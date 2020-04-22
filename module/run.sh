echo 'starting module'

# sleep time provided in environment variables.  If not provided, pick reasonable defaults
SleepTime="${SleepTime:=24}"
SleepUnit="${SleepUnit:=h}"

# ensure sleep unit is a valid value, otherwise default to hours
case $SleepUnit in
    s|h|m|d)
	;;
    *) 
	echo '********** Invalid or Missing SleepUnit.  if SleepUnit env variable was provided, it must be s, m, d, or h..  defaulting to h ***********' 
        SleepUnit=h
	;;
esac

echo 'sleep time between runs: ' $SleepTime $SleepUnit
echo 'environment variables'
export

#run forever
while :
do
   echo 'removing unused docker images at ' $(date)
   # here's the magic..  Call the /images/prune API, with dangling=false to prune all unused images (not just <none>:<none> ones)
   curl -X POST -s --unix-socket /var/run/docker.sock http://localhost/images/prune?filters=%7B%22dangling%22%3A%20%5B%22false%22%5D%7D
   echo 'sleeping for ' $SleepTime $SleepUnit
   # sun's getting real low, big guy...  go to sleep
   sleep ${SleepTime}${SleepUnit}
done
