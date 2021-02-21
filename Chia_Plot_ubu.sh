#!/bin/bash

# Last update 2020-12-13

# Run as local user
# bash Chia_Plot_ubu.sh

# How many chia process per temp drive: 1-4; need 500GB per process
# Warning: only NVMe temp drives can have Pass > 1
NumOfPasses=4
# How long to stagger each chia process in seconds
Stagger=1
# Chia -b value in MiB, set this value 0 for calculated buffer instead
Buffer=10000
# Number of sorting Buckets, 16-128, higher value = more writes
# Recommend 128 for SSD
Buckets=128
# Number of threads
Threads=2
# chia parameters
KSize=32
# These array entries should equal NumOfPasses
TempDirList=("/mnt/Temp0/Temp" "/mnt/Temp1/Temp" "/mnt/Temp0/Temp" "/mnt/Temp1/Temp")
TwoDirList=("/mnt/Temp0/Final" "/mnt/Temp1/Final" "/mnt/Temp0/Final" "/mnt/Temp1/Final")
FinalDirList=("/mnt/Temp0/Final" "/mnt/Temp1/Final" "/mnt/Temp0/Final" "/mnt/Temp1/Final")
# Where to put all log files
LogDir=~/chia/

# Logging function
LOG ()
{
  echo "[$(date --rfc-3339=seconds)]: $*"
}

LOG Setting buffer: $Buffer

cd ~/chia-blockchain
. ./activate

for (( Pass=0; Pass < $NumOfPasses ; Pass++ ))
do
  TempDir=${TempDirList[$Pass]}
  TwoDir=${TwoDirList[$Pass]}
  FinalDir=${FinalDirList[$Pass]}
  LogFile=$(printf $LogDir"chia%02d".log $Pass)
  LOG Command: nohup chia plots create -k $KSize -n 1 -u $Buckets -r $Threads -b $Buffer -t $TempDir -2 $TwoDir -d $FinalDir
  LOG Logfile: $LogFile
#  nohup chia plots create -k $KSize -n 1 -u $Buckets -r $Threads -b $Buffer -t $TempDir -2 $TwoDir -d $FinalDir >> $LogFile 2>&1 &
  LOG Staggering next chia process by $Stagger
  sleep $Stagger
done

deactivate
