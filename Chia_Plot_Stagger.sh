#!/bin/bash

# NO LONGER MAINTAINED as of 2020-09-15
# use Chia_Plot_Public.sh

# Run as chia
# Kill all chia processes, remove all tmp and log files before running:
# nohup bash Chia_Plot_Stagger.sh >> Chia_Plot_Stagger.log 2>&1 &

# TODO add ability to stagger initial chia plots

# Chia -b value in MiB, set this value 0 for calculated buffer instead
Buffer=5000
# Max memory for Chia -b to use amongst all chia processes in MiB
MaxMemory=75000
# Each chia process overhead memory needed in MiB
ProcessOverhead=500
# Number of temp drives used for plotting
NumOfDrives=5
# How many staggered chia process per temp drive: 1-3; need 500GB per process
# Warning: only NVMe temp drives can have Pass > 1
NumOfPasses=3
# These array entries should equal NumOfDrives * NumOfPasses
# If n passes, list the temp drives in sequential order n times
TempDirList=("/mnt/TempA00" "/mnt/TempA01" "/mnt/TempA02" "/mnt/TempA03" "/mnt/TempA04" "/mnt/TempA00" "/mnt/TempA01" "/mnt/TempA02" "/mnt/TempA03" "/mnt/TempA04" "/mnt/TempA00" "/mnt/TempA01" "/mnt/TempA02" "/mnt/TempA03" "/mnt/TempA04")
TwoDirList=("/mnt/FinalA00" "/mnt/FinalA01" "/mnt/FinalA02" "/mnt/FinalA03" "/mnt/FinalA04" "/mnt/FinalA05" "/mnt/FinalA06" "/mnt/FinalA07" "/mnt/FinalA08" "/mnt/FinalA09" "/mnt/FinalA10" "/mnt/FinalA11" "/mnt/FinalA12" "/mnt/FinalA13" "/mnt/FinalA14")
FinalDirList=("/mnt/FinalA00" "/mnt/FinalA01" "/mnt/FinalA02" "/mnt/FinalA03" "/mnt/FinalA04" "/mnt/FinalA05" "/mnt/FinalA06" "/mnt/FinalA07" "/mnt/FinalA08" "/mnt/FinalA09" "/mnt/FinalA10" "/mnt/FinalA11" "/mnt/FinalA12" "/mnt/FinalA13" "/mnt/FinalA14")
# Which CPU to assign each chia process, check /proc/cpuinfo
# Reserved CPU 0,31 for RCU.
# For advanced optimizations, make changes to /etc/default/grub:
# GRUB_CMDLINE_LINUX_DEFAULT="pcie_aspm=off rcu_nocbs=1-30 rcu_nocb_poll"
CPUBindList=(1 8 23 30 2 9 22 29 3 10 21 28 4 11 20)
# Where to put all log files
LogDir="/home/chia/"
# How long to stagger each chia process
Stagger=1m
# Time to wait before trying to launch another chia process
WaitTime=30m
# Chia K size to plot
KSize=32
# Phase keywords
PhaseKeywordList=("Starting phase 1/4:" "Starting phase 2/4:" "Starting phase 3/4:")

# Logging function
LOG ()
{
  echo "[$(date --rfc-3339=seconds)]: $*"
}

# Calculate -b buffer for each chia process
if (( Buffer == 0 )) ; then
  Overhead=$(( ProcessOverhead * NumOfDrives * NumOfPasses ))
  MemMinusOverhead=$(( MaxMemory - Overhead ))
  Buffer=$(( MemMinusOverhead / NumOfDrives / NumOfPasses ))
fi
LOG Setting buffer: $Buffer

# Calculate log filenames
for (( Pass=0; Pass < $NumOfPasses ; Pass++ ))
do
  for (( Drive=0; Drive < $NumOfDrives ; Drive++ ))
  do
    Index=$(( Pass * NumOfDrives + Drive ))
    LogFileList[$Index]=$(printf $LogDir"%dp%02d".log $Pass $Drive)
  done
done

# Assign which log to check and set initial Phase counters
for (( Pass=0; Pass < $NumOfPasses ; Pass++ ))
do
  for (( Drive=0; Drive < $NumOfDrives ; Drive++ ))
  do
    Index=$(( Pass * NumOfDrives + Drive ))
    LogIndex=$(( Index + NumOfDrives ))
    MaxIndex=$(( NumOfPasses * NumOfDrives ))
    if (( LogIndex >= MaxIndex )) ; then
      LogIndex=$(( LogIndex - MaxIndex ))
    fi
    LOG Index $Index will check ${LogFileList[$LogIndex]}
    CheckLogList[$Index]=${LogFileList[$LogIndex]}
    if [ -f "${CheckLogList[$Index]}" ] ; then
      Phase1CountList[$Index]=$( grep -c "${PhaseKeywordList[0]}" ${CheckLogList[$Index]} )
      Phase2CountList[$Index]=$( grep -c "${PhaseKeywordList[1]}" ${CheckLogList[$Index]} )
      Phase3CountList[$Index]=$( grep -c "${PhaseKeywordList[2]}" ${CheckLogList[$Index]} )
    else
      if (( Pass == 0 )) ; then
        # Only set the first pass of each temp drive to start a chia process
        Phase1CountList[$Index]=-1
      else
        Phase1CountList[$Index]=0
      fi
      Phase2CountList[$Index]=0
      Phase3CountList[$Index]=0
    fi
    LOG Phase 1 Count for Index $Index is ${Phase1CountList[$Index]}
    LOG Phase 2 Count for Index $Index is ${Phase2CountList[$Index]}
    LOG Phase 3 Count for Index $Index is ${Phase3CountList[$Index]}
  done
done

# Loop forever to launch chia processes
while : ; do
  cd ~/chia-blockchain
  . ./activate
  for (( Pass=0; Pass < NumOfPasses ; Pass++ )) ; do
    for (( Drive=0; Drive < NumOfDrives ; Drive++ )) ; do
      # Set all the variables needed for this loop
      Index=$(( Pass * NumOfDrives + Drive ))
      TempDir=${TempDirList[$Index]}
      TwoDir=${TwoDirList[$Index]}
      FinalDir=${FinalDirList[$Index]}
      LogFile=${LogFileList[$Index]}
      CheckLog=${CheckLogList[$Index]}
      Phase1Count=${Phase1CountList[$Index]}
      Phase2Count=${Phase2CountList[$Index]}
      Phase3Count=${Phase3CountList[$Index]}
      CPUBind=${CPUBindList[$Index]}
      CheckProcess=" ${CPUBind} chia"
      ActiveProcesses=$( ps -eo psr,comm,pid | grep -w chia )
      LOG Active Processes: $ActiveProcesses
      # Check if Chia process is running
      if [[ "$ActiveProcesses" =~ .*"$CheckProcess".* ]] ; then
        # Chia process is running
        LOG Found Process: $CheckProcess
      else
        # Chia process is NOT running
        LOG No Process Found: $CheckProcess
        # Check if CheckLog file exists
        if [ -f "$CheckLog" ] ; then
          # CheckLog exists, calculate current phase counts
          CurPhase1Count=$( grep -c "${PhaseKeywordList[0]}" $CheckLog )
          CurPhase2Count=$( grep -c "${PhaseKeywordList[1]}" $CheckLog )
          CurPhase3Count=$( grep -c "${PhaseKeywordList[2]}" $CheckLog )
        else
          # CheckLog does NOT exist, set current phase 3 count to zero
          CurPhase1Count=0
          CurPhase2Count=0
          CurPhase3Count=0
        fi
        LOG Current Phase 1 Count: $CurPhase1Count vs $Phase1Count
        LOG Current Phase 2 Count: $CurPhase2Count vs $Phase2Count
        LOG Current Phase 3 Count: $CurPhase3Count vs $Phase3Count
        # Check if Phase 3 count increased
        if (( CurPhase3Count > Phase3Count )) ; then
          # Phase 3 count increased, launch chia process
          LOG Command: nohup numactl -C $CPUBind chia plots create -k $KSize -n 1 -b $Buffer -t $TempDir -2 $TwoDir -d $FinalDir
          LOG Logfile: $LogFile
          nohup numactl -C $CPUBind chia plots create -k $KSize -n 1 -b $Buffer -t $TempDir -2 $TwoDir -d $FinalDir >> $LogFile 2>&1 &
          Phase1CountList[$Index]=$CurPhase1Count
          Phase2CountList[$Index]=$CurPhase2Count
          Phase3CountList[$Index]=$CurPhase3Count
          LOG Staggering next chia process by $Stagger
          sleep $Stagger
        else
          # Phase 3 count is the same
          LOG Phase 3 has not started for $CheckLog
          # Check if Phase 2 count increased
          if (( CurPhase2Count > Phase2Count )) ; then
            # Phase 2 count increased, launch chia process
            LOG Command: nohup numactl -C $CPUBind chia plots create -k $KSize -n 1 -b $Buffer -t $TempDir -2 $TwoDir -d $FinalDir
            LOG Logfile: $LogFile
            nohup numactl -C $CPUBind chia plots create -k $KSize -n 1 -b $Buffer -t $TempDir -2 $TwoDir -d $FinalDir >> $LogFile 2>&1 &
            Phase1CountList[$Index]=$CurPhase1Count
            Phase2CountList[$Index]=$CurPhase2Count
            Phase3CountList[$Index]=$CurPhase3Count
            LOG Staggering next chia process by $Stagger
            sleep $Stagger
          else
            # Phase 2 count is the same
            LOG Phase 2 has not started for $CheckLog
            # Check if Phase 1 count increased
            if (( Phase1Count < 0 )) ; then
              # Phase 1 count is -1, launch chia process
              LOG Command: nohup numactl -C $CPUBind chia plots create -k $KSize -n 1 -b $Buffer -t $TempDir -2 $TwoDir -d $FinalDir
              LOG Logfile: $LogFile
              nohup numactl -C $CPUBind chia plots create -k $KSize -n 1 -b $Buffer -t $TempDir -2 $TwoDir -d $FinalDir >> $LogFile 2>&1 &
              Phase1CountList[$Index]=$CurPhase1Count
              Phase2CountList[$Index]=$CurPhase2Count
              Phase3CountList[$Index]=$CurPhase3Count
              LOG Staggering next chia process by $Stagger
              sleep $Stagger
            fi
          fi
        fi
      fi
    done
  done
  deactivate
  LOG Waiting for $WaitTime
  sleep $WaitTime
done
