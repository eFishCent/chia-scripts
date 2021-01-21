#!/bin/bash

# Last update 2020-01-20

# Run as local user
# bash Kill_Slow_Nodes [Sub-block Threshold]

WaitTime=10s
ChiaDir="/Applications/Chia.app/Contents/Resources/app.asar.unpacked/daemon"

SBThreshold="$1"

while : ; do
  cd $ChiaDir
  IFS=$'\n' read -r -d '' -a NodeConnections < <( ./chia show -c && printf '\0' )
  for Line in "${NodeConnections[@]}" ; do
    LineArray=($Line)
    case $Line in
      "FULL_NODE"*)
        NodeID=${LineArray[3]%...}
        StartNewNode=1
        ;;
      "                                                 -SB Height:"*)
        SBHeight=${LineArray[2]}
        EndNewNode=1
        ;;
    esac
  if (( EndNewNode == 1 )) ; then
    if (( StartNewNode == 1 )) ; then
      if (( SBHeight < SBThreshold )) ; then
        ./chia show -r $NodeID
      fi
    fi
    StartNewNode=0
    EndNewNode=0
  fi
  done
  sleep $WaitTime
done
