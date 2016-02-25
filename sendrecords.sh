#!/usr/bin/env bash
echo "bash version: $(/usr/bin/env bash -version)"

# Send record in a loop on tcp session
# This script requires a server to be established elsewhere listening
# to the session originated here (i.e. "nc -l 11111", or some other TCP 
# server listening on the port
#
# @todo: pass in optional file(s) to use as records
# @todo: enhance script to send data in multiple sessions
# @todo: deal when payload length > 256 as xxd only supports up to 256 columns

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
rec[0]="0100001c0010000080080010aacdabcdabcdabcd1234567812345678";
rec[1]="0100001c0010000080080010bbcdabcdabcdabcd1234567812345678";
rec[2]="0100001c0010000080080010cccdabcdabcdabcd1234567812345678";
rec[3]="0100001c0010000080080010ddcdabcdabcdabcd1234567812345678";
rec[4]="0100001c0010000080080010eecdabcdabcdabcd1234567812345678";
len=$((${#rec[0]}/2))
login="sent_${$}.hex"
logout="output_${$}.hex"
rem_pid=
mflag=0

usage="$(basename $0):[-HDl] [-i <interval_sec>] [-r <repeat number>] \
[-h <dest host>] [-s <src port>] [-d <dest port>] [-c <capture-file>] \
[-m <mss>] \
\n  -H: display this message \
\n  -D: special script debug mode \
\n  -l: log sent and received records \
\n  -i <sec>: interval between records in seconds (or fractions) \
\n  -r <num>: number of records to send \
\n  -h <ip>: destination host IP for mapper session \
\n  -s <sport>: source port for mapper session \
\n  -d <dport>: destination port for mapper session \
\n  -a <ip>: host IP of arbiter, i.e. destination address of reducer session \
\n  -e <dport>: destination port of reducer session \
\n  -f <sport>: source port of reducer session \
\n  -c <filename>: filename to capture tcpdump when -D flag is set \
\n  -n <host>: hostname or IP address of reducer node, used for ssh connection\
\n  -m <mss>: mss size to test (tests all possible sizes of keys and values)
\n            overrides static record
\n"

# Parse any options
while getopts 'HDli:r:h:s:d:a:e:f:c:n:m:' OPTION
do
  case $OPTION in
  H)  printf "Usage: $usage"
      exit 0
      ;;
  D)  debug=1
      # for local debugging/development of script through localhost.
      # with the remote host in a listening connection.  For real Arbiter
      # testing the remote also makes an active connection.
      ;;
  l)  log=1
      ;;
  i)  interval="$OPTARG"
      ;;
  r)  repeat="$OPTARG"
      ;;
  h)  host="$OPTARG"
      ;;
  s)  sport_arg="-p $OPTARG"
      ;;
  d)  dport="$OPTARG"
      ;;
  a)  arbiter="$OPTARG"
      ;;
  e)  eport="$OPTARG"
      ;;
  f)  esport_arg="-p $OPTARG"
      ;;
  c)  fileout="$OPTARG"
      cflag=1
      ;;
  n)  nodessh="$OPTARG"
      ;;
  m)  mss="$OPTARG"
      rec=
      mflag=1
      len=$mss
      repeat=$(($mss-12-1))
      ;;
  ?)  printf "Usage: $usage" >&2
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
  [ $log = 1 ] && { nc -d -l $dport | xxd -p -c $len > tmp.hex & } \
               || { nc -d -l $dport | xxd -p -c $len & }
else
  # remote host
  # set up logging regardless of parameter flag
  log=1
  if [ $debug = 1 ]
  then
    # for testing script across multiple hosts without a ximm
    printf "Start remote listening socket: \nssh %s nc -l %s | xxd -p -c %s &\n" \
           $nodessh $dport $len
    ssh_cmd="ncat -l $dport --recv-only -o output.bin >/dev/null 2>&1 & echo \$! "
    rem_pid=$( ssh -n $nodessh "$ssh_cmd" )
  else
    printf "Start remote active socket: \
            \nssh -n %s ncat %s %s %s --recv-only -o output.bin \n" \
            $nodessh "$esport_arg" $arbiter $eport $len
    ssh_cmd="ncat $esport_arg $arbiter $eport --recv-only -o output.bin >/dev/null 2>&1 & echo \$! "
    rem_pid=$( ssh -n $nodessh "$ssh_cmd" )
  fi
fi

# If set enable tcpdump capture of the session, needs passwd-less sudo support
if [ "$cflag" ] && [ "$debug" ]
then
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

while ((repeat > 0))
do
    if [ $mflag = 1 ] 
    then
      record=$(java -cp xockets-hadoop-transport-1.0-SNAPSHOT-jar-with-dependencies.jar com.xockets.XocketsEncode $mss 1 $repeat $(($mss-12-$repeat))) 
    else 
      record=${rec[$(($repeat%${#rec[@]}))]}
    fi
    record=${record,,}
    echo -n "."
    echo -n $record | xxd -r -p >> inputfile;
    # Strip bytes 3 - 7 for the log as the hw output doesn't match
    [ $log = 1 ] && echo ${record:0:2}${record:16} >> $login
    sleep $interval;
    let repeat--
done
echo

# Sleep a bit before closing the sessions.
sleep 3

# Clean up background process
kill -9 $child $((child - 1))
if [ "$tcp_pid" ]
then 
  sudo kill $tcp_pid
fi
if [ "$rem_pid" ]
then 
  ssh -n $nodessh "kill -9 $rem_pid"
fi  
rm inputfile

# Validate the data
if [ $log = 1 ] 
then
  cmd="while read in; do echo \${in:0:2}\${in:16} >> $logout; done < tmp.hex"
  if [ "$host" != "localhost" ] 
  then
    # Get the output file from remote host
    ssh -n $nodessh "xxd -p -c$len output.bin > tmp.hex"
    ssh -n $nodessh "$cmd"
    sleep 1
    scp $nodessh:$logout .
  else
    eval $cmd
  fi
  printf "Diffing input and output records\n"
  ls -l *${$}*
  diff $login $logout
fi





