#!/usr/bin/env bash

# Send record in a loop on tcp session
# This script requires a server to be established elsewhere listening
# to the session originated here (i.e. "nc -l 11111", or some other TCP 
# server listening on the port
#
# @todo: pass in session destination address and port as parameters
# @todo: pass in optional file(s) to use as records
# @todo: pass in parameter for how long to run the test
# @todo: when loop terminates or script is killed, clean up child process
# @todo: enhance script to send data in multiple sessions
# @todo: validate received data (as received data is handled elsewhere
# not clear if that can be handled here.  If using a single driver system
# with `netns`, perhaps we can compare output after it is written to a file

loop=1
interval=5

# Parse any options
while getopts 'l:i:' OPTION
do
  case $OPTION in
  l)  loop="$OPTARG"
      ;;
  i)  interval="$OPTARG"
      ;;
  ?)  printf "Usage: %s:[-i <interval_sec>] [-l <loop number>] args\n" $(basename $0) >&2
      exit 2
      ;;
  esac
done
shift $(($OPTIND - 1))
# Parse any remaining arguments

rec="0100001C0010000080080010ABCDABCDABCDABCD1234567812345678";

echo -n > inputfile
tail -f inputfile | nc "localhost" "5555" &
echo $rec;
while ((loop > 0))
do
    echo -n $rec | xxd -r -p >> inputfile;
    sleep $interval;
    let loop--
done


