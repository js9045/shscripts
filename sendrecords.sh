#!/usr/bin/env bash

# Send record in a loop on tcp session
# This script requires a server to be established elsewhere listening
# to the session originated here (i.e. "nc -l 11111", or some other TCP 
# server listening on the port
#
# @todo: pass in optional file(s) to use as records
# @todo: enhance script to send data in multiple sessions
# @todo: deal when payload length > 256 as xxd only supports up to 256 columns
# @todo: support active remote host

# Flags and default parameters, can be overriden through options
cflag=
log=0
repeat=1
interval=1
host="localhost"
dport="5555"
eport=
sport_arg=
esport_arg=
tcp_pid=
arbiter=
debug=0
rec="0100001c0010000080080010abcdabcdabcdabcd1234567812345678";
len=28
login="sent_${$}.hex"
logout="output_${$}.hex"

# Parse any options
while getopts 'Dlr:i:h:s:d:c:a:e:f:' OPTION
do
  case $OPTION in
  D)  debug=1
      # for local debugging/development of script through localhost.
      # with the remote host in a listening connection.  For real Arbiter
      # testing the remote also makes an active connection.
      ;;
  l)  log=1
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
  a)  arbiter="$OPTARG"
      ;;
  e)  eport="$OPTARG"
      ;;
  f)  esport_arg="-p $OPTARG"
      ;;
  ?)  printf "Usage: %s:[-l] [-i <interval_sec>] [-r <repeat number>] [-h <dest host>] [-s <src port>] [-d <dest port>] [-c <capture-file>] args\n" $(basename $0) >&2
      exit 2
      ;;
  esac
done
shift $(($OPTIND - 1))
# Parse any remaining arguments
# ...

# Set up the remote session
if [ "$host" == "localhost" ] 
then
  printf "Start listening socket: nc -d -l %s | xxd -p -c %s &\n" $dport $len
  [ $log = 1 ] && { nc -d -l $dport | xxd -p -c $len > $logout & } \
               || { nc -d -l $dport | xxd -p -c $len & }
else
  # remote host
  # set up logging regardless of parameter flag
  log=1
  if [ $debug = 1 ]
  then
    printf "Start remote listening socket: ssh %s nc -l %s | xxd -p -c %s &\n" $host $dport $len
    ssh $host "sh -c 'nc -d -l $dport | xxd -p -c $len >$logout 2>&1 &'"
  else
    printf "Start remote active socket: ssh %s nc %s %s %s | xxd -p -c %s &\n" $host "$esport_arg" $arbiter $eport $len
    ssh $host "sh -c 'nc $esport_arg $arbiter $eport | xxd -p -c $len >$logout 2>&1 &'"
  fi
fi

# If set enable tcpdump capture of the session, needs passwd-less sudo support
if [ "$cflag" ]
then
# sudo tcpdump -i lo0 -n -w $fileout dst port $dport &
  sudo tcpdump -i lo0 -n dst port $dport > $fileout &
  tcp_pid=$!
fi
sleep 1

printf "Start transmit socket: nc %s %s %s &\n" $sport_arg $host $dport
[ $log = 1 ] && echo -n > $login

echo -n > inputfile
tail -f inputfile | nc $sport_arg $host $dport &
# Store the background process pid
child=$!
printf "%s\n------\n" $rec
while ((repeat > 0))
do
    echo -n "."
    echo -n $rec | xxd -r -p >> inputfile;
    [ $log = 1 ] && echo $rec >> $login
    sleep $interval;
    let repeat--
done
echo

# Clean up background process
kill -9 $child $((child - 1))
if [ "$tcp_pid" ]
then 
  sudo kill $tcp_pid
fi
rm inputfile

sleep 3
# Validate the data
if [ $log = 1 ] 
then
  if [ "$host" != "localhost" ] 
  then
    # Get the output file from remote host
    scp $host:$logout .
  fi
  printf "Diffing input and output records\n"
  diff $login $logout
fi





