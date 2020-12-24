#!/bin/bash

# Last update 2020-12-24

# Run as local user
# Requires packages installed: numactl
# Kill all chia processes, remove all tmp and log files before running:
# nohup bash Chia_Plot_Public.sh >> Chia_Plot_Public.log 2>&1 &

# Chia -b value in MiB
Buffer=5000
# Number of sorting Buckets, 16-128, higher value = more writes
# Recommend 128 for SSD
Buckets=128
# Number of chia processes used for plotting
NumOfChiaProc=30
# These array entries should equal NumOfChiaProc
TempDirList=("/mnt/TempA04" "/mnt/TempA00" "/mnt/TempA01" "/mnt/TempA02" "/mnt/TempA03" "/mnt/TempA00" "/mnt/TempA01" "/mnt/TempA02" "/mnt/TempA03" "/mnt/TempA05" "/mnt/TempA04" "/mnt/TempA05" "/mnt/TempA04" "/mnt/TempA05" "/mnt/TempA04" "/mnt/TempA05" "/mnt/TempA00" "/mnt/TempA01" "/mnt/TempA02" "/mnt/TempA03" "/mnt/TempA00" "/mnt/TempA01" "/mnt/TempA02" "/mnt/TempA03" "/mnt/TempA05" "/mnt/TempA04" "/mnt/TempA05" "/mnt/TempA04" "/mnt/TempA05" "/mnt/TempA04")
TwoDirList=("/mnt/FinalA00/Temp" "/mnt/FinalA01/Temp" "/mnt/FinalA02/Temp" "/mnt/FinalA03/Temp" "/mnt/FinalA04/Temp" "/mnt/FinalA05/Temp" "/mnt/FinalA06/Temp" "/mnt/FinalA07/Temp" "/mnt/FinalA08/Temp" "/mnt/FinalA09/Temp" "/mnt/FinalA10/Temp" "/mnt/FinalA11/Temp" "/mnt/FinalA12/Temp" "/mnt/FinalA13/Temp" "/mnt/FinalA14/Temp" "/mnt/FinalA15/Temp" "/mnt/FinalA16/Temp" "/mnt/FinalA17/Temp" "/mnt/FinalA18/Temp" "/mnt/FinalA19/Temp" "/mnt/FinalA20/Temp" "/mnt/FinalA21/Temp" "/mnt/FinalA22/Temp" "/mnt/FinalA23/Temp" "/mnt/FinalA24/Temp" "/mnt/FinalA25/Temp" "/mnt/FinalA26/Temp" "/mnt/FinalA27/Temp" "/mnt/FinalA28/Temp" "/mnt/FinalA29/Temp")
FinalDirList=("/mnt/FinalA00/Temp" "/mnt/FinalA01/Temp" "/mnt/FinalA02/Temp" "/mnt/FinalA03/Temp" "/mnt/FinalA04/Temp" "/mnt/FinalA05/Temp" "/mnt/FinalA06/Temp" "/mnt/FinalA07/Temp" "/mnt/FinalA08/Temp" "/mnt/FinalA09/Temp" "/mnt/FinalA10/Temp" "/mnt/FinalA11/Temp" "/mnt/FinalA12/Temp" "/mnt/FinalA13/Temp" "/mnt/FinalA14/Temp" "/mnt/FinalA15/Temp" "/mnt/FinalA16/Temp" "/mnt/FinalA17/Temp" "/mnt/FinalA18/Temp" "/mnt/FinalA19/Temp" "/mnt/FinalA20/Temp" "/mnt/FinalA21/Temp" "/mnt/FinalA22/Temp" "/mnt/FinalA23/Temp" "/mnt/FinalA24/Temp" "/mnt/FinalA25/Temp" "/mnt/FinalA26/Temp" "/mnt/FinalA27/Temp" "/mnt/FinalA28/Temp" "/mnt/FinalA29/Temp")
# Which CPU to assign each chia process, check /proc/cpuinfo
# Reserved CPU 16,31 for RCU
# Make sure you use taskset -cp 31 [PID] on chia run_daemon process
# For advanced optimizations, make changes to /etc/default/grub:
# GRUB_CMDLINE_LINUX_DEFAULT="pcie_aspm=off rcu_nocbs=0-15,17-30 rcu_nocb_poll"
CPUBindList=(0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 17 18 19 20 21 22 23 24 25 26 27 28 29 30)
# Where to put all log files
LogDir="/home/chia/"
# How long to stagger each chia process
Stagger=1s
# How often to check on if new chia plot needs to be started
WaitTime=5m
# Chia K size to plot
KSize=32
# Number of threads; should be left at 1 since using numactl
Threads=1

# Logging function
LOG ()
{
  echo "[$(date --rfc-3339=seconds)]: $*"
}

TotalWaits=0

SHOW_TOTAL_WAITS ()
{
  if (( TotalWaits > 0 )) ; then
    echo
    LOG Total waits: $TotalWaits
    TotalWaits=0
  fi
}

# LOG Setting buffer: $Buffer

# Calculate log filenames
for (( ChiaProc=0; ChiaProc < $NumOfChiaProc ; ChiaProc++ ))
do
  LogFileList[$ChiaProc]=$(printf $LogDir"chia%02d".log $ChiaProc)
done

# Attempt to launch chia processes
while : ; do
  cd ~/chia-blockchain
  . ./activate
  for (( ChiaProc=0; ChiaProc < $NumOfChiaProc ; ChiaProc++ ))
  do
    TempDir=${TempDirList[$ChiaProc]}
    TwoDir=${TwoDirList[$ChiaProc]}
    FinalDir=${FinalDirList[$ChiaProc]}
    LogFile=${LogFileList[$ChiaProc]}
    CPUBind=${CPUBindList[$ChiaProc]}
    CheckProcess=" ${CPUBind} chia"
    ActiveProcesses=$( ps -eo psr,comm,pid | grep -w chia )
#    LOG Active Processes: $ActiveProcesses
    if [[ "$ActiveProcesses" =~ .*"$CheckProcess".* ]] ; then
#      LOG Found Process: $CheckProcess
      sleep $Stagger
    else
#      LOG No Process Found: $CheckProcess
      SHOW_TOTAL_WAITS
      LOG Command: nohup numactl -C $CPUBind chia plots create -k $KSize -n 1 -u $Buckets -r $Threads -b $Buffer -t $TempDir -2 $TwoDir -d $FinalDir
      LOG Logfile: $LogFile
      nohup numactl -C $CPUBind chia plots create -k $KSize -n 1 -u $Buckets -r $Threads -b $Buffer -t $TempDir -2 $TwoDir -d $FinalDir >> $LogFile 2>&1 &
#      LOG Staggering next chia process by $Stagger
      sleep $Stagger
    fi
  done
  deactivate
  if [[ "$ActiveProcesses" == "$PrevActiveProcesses" ]] ; then
    echo -n "."
  else
    SHOW_TOTAL_WAITS
    LOG Active processes: $ActiveProcesses
    LOG Waiting $WaitTime for each dot:
    echo -n "."
    PrevActiveProcesses=$ActiveProcesses
  fi
  sleep $WaitTime
  TotalWaits=$(( TotalWaits + 1 ))
done
