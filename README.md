## shscripts

### Example:
```
./sendrecords.sh -n eipi -r 10 -h 10.0.0.17 -s 5454 -d 5555 -a 10.6.6.6 -e 6666 -f 6660
```

### Usage:
```
sendrecords.sh[-HDl] [-i <interval_sec>] [-r <repeat number>] [-h <dest host>] [-s <src port>] [-d <dest port>] [-c <capture-file>] 
  -H: display this message 
  -D: special script debug mode 
  -l: log sent and received records 
  -i <sec>: interval between records in seconds (or fractions) 
  -r <num>: number of records to send 
  -h <ip>: destination host IP for mapper session 
  -s <sport>: source port for mapper session 
  -d <dport>: destination port for mapper session 
  -a <ip>: host IP of arbiter, i.e. destination address of reducer session 
  -e <dport>: destination port of reducer session 
  -f <sport>: source port of reducer session 
  -c <filename>: filename to capture tcpdump when -D flag is set 
  -n <host>: hostname or IP address of reducer node, used for ssh connection
```

