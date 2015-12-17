#!/bin/bash

# Send record in a loop on tcp session
# @todo: pass in session destination address and port as parameters
# @todo: pass in file(s) to use as records
# @todo: pass in parameter for how long to run the test
# @todo: when loop terminates or script is killed, clean up child process

rec="0100001C0010000080080010ABCDABCDABCDABCD1234567812345678";

echo -n > inputfile
tail -f inputfile | nc localhost 11111 &
echo $rec;
while true
do
    echo -n $rec | xxd -r -p >> inputfile;
    sleep 5;
done


