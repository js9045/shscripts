#!/usr/bin/env bash

# Send record in a loop on tcp session
# This script requires a server to be established elsewhere listening
# to the session originated here (i.e. "nc -l 11111", or some other TCP 
# server listening on the port
#
# @todo: pass in optional file(s) to use as records
# @todo: enhance script to send data in multiple sessions
# @todo: validate received data (as received data is handled elsewhere
# not clear if that can be handled here.  If using a single driver system
# with `netns`, perhaps we can compare output after it is written to a file

# Default parameters, can be overriden through options
cflag=
log=
repeat=1
interval=1
host="localhost"
dport="5555"
sport_arg=
tcp_pid=
rec="0100001c0010000080080010abcdabcdabcdabcd1234567812345678";

# Parse any options
while getopts 'lr:i:h:s:d:c:' OPTION
do
  case $OPTION in
  l)  log=1
      logfile="sent_${$}.hex"
      echo -n > $logfile
      ;;
  h)  host="$OPTARG"
      ;;
  d)  dport="$OPTARG"
      ;;
  s)  sport_arg="-p $OPTARG"
      ;;
  r)  repeat="$OPTARG"
      ;;
  i)  interval="$OPTARG"
      ;;
  c)  fileout="$OPTARG"
      cflag=1
      ;;
  ?)  printf "Usage: %s:[-l] [-i <interval_sec>] [-r <repeat number>] [-h <dest host>] [-s <src port>] [-d <dest port>] [-c <capture-file>] args\n" $(basename $0) >&2
      exit 2
      ;;
  esac
done
shift $(($OPTIND - 1))
# Parse any remaining arguments
# ...

# If set enable tcpdump capture of the session, needs passwd-less sudo support
if [ "$cflag" ]
then
#  sudo tcpdump -i lo0 -n -w $fileout dst port $dport &
  sudo tcpdump -i lo0 -n dst port $dport > $fileout &
  tcp_pid=$!
fi
sleep 1

echo $!
printf "Calling nc as: nc %s %s %s &\n" $sport_arg $host $dport
echo -n > inputfile
tail -f inputfile | nc $sport_arg $host $dport &
# Store the background process pid
child=$!
echo $rec;
while ((repeat > 0))
do
    echo -n $rec | xxd -r -p >> inputfile;
    if [ "$log" ]
    then
      echo $rec >> $logfile
    fi
    sleep $interval;
    let repeat--
done

# Clean up background process
kill -9 $child $((child - 1))
if [ "$tcp_pid" ]
then 
  sudo kill $tcp_pid
fi



