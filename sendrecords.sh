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

rec="0100001C0010000080080010ABCDABCDABCDABCD1234567812345678";

echo -n > inputfile
tail -f inputfile | nc 192.168.10.117 5555 &
echo $rec;
while true
do
    echo -n $rec | xxd -r -p >> inputfile;
    sleep 5;
done


