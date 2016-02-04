#!/bin/bash
#Configuration
timespan=1814400
threshold_warn=0.8
threshold_crit=0.25
now=$(date +%s)
cd /home/nagios/check-backupstate
#Initialize counters
echo "0" >> tm_users_checked
echo "0" >> tm_active_backup_counter
echo "0" >> tm_old_backup_counter
echo "0" >> tm_not_having_counter
echo "0" >> sf_users_checked
echo "0" >> sf_active_backup_counter
echo "0" >> sf_old_backup_counter 
echo "0" >> sf_not_having_counter
echo "0" >> total_users_checked
echo "0" >> total_active_backup_counter
echo "0" >> total_old_backup_counter
echo "0" >> total_not_having_counter
echo "0" >> total_backup_succesful_quota

#Create lists
touch tm_old_backup_users tm_not_having_backup_users tm_having_multiple_users sf_old_backup_users sf_not_having_backup_users sf_having_multiple_users

#Check TimeMachine in /srv/backup
cat /etc/passwd | cut -f1 -d : > passwd_out
grep -Fxv -f blacklist passwd_out | while read LINE
do
	users_checked=$((users_checked + 1))
	echo $users_checked > tm_users_checked
	#if there is a Folder belonging to user
	if [ $( ls -l /srv/backup | awk '{print $3}' | grep -o $LINE | wc -l) -gt 0 ]; then
    
    #Are there multiple folders belonging to this user?
		if [ $(ls -l /srv/backup | awk '{print $3}' | grep -o $LINE | wc -l) -gt 1 ]; then
			 echo "$LINE" >> tm_having_multiple_users
			continue
	#Calculate epoch from last_backup
		else
            folder=$(ls -l /srv/backup | grep $LINE | awk '{print $9}')
            directory="/srv/backup/"
			last_backup=$( stat --format %Y $(ls -t $(find $directory$folder -type f) | head -n 1) )
		fi
        
	#Calculate Delta between now and last_backup
		delta=`expr $now - $last_backup`
	#Transform 3 weeks in seconds and compare against delta 3weeks=1814400
		if [ $delta -gt $timespan ]; then
			old_backup_counter=$((old_backup_counter + 1))
			echo "$LINE" >> tm_old_backup_users
			echo $old_backup_counter > tm_old_backup_counter
		else
			active_backup_counter=$((active_backup_counter + 1))
			echo $active_backup_counter > tm_active_backup_counter
		fi
	else
		not_having_counter=$((not_having_counter + 1))
		echo "$LINE" >> tm_not_having_backup_users
		echo $not_having_counter > tm_not_having_counter
	fi
done

#Store TM Performance Indicators
tm_users_checked=$(cat tm_users_checked)
tm_active_backup_counter=$(cat tm_active_backup_counter)
tm_old_backup_counter=$(cat tm_old_backup_counter)
tm_not_having_counter=$(cat tm_not_having_counter)

#----------------------------------------------------------------------------------------------------------
grep -Fx -f blacklist linux_users | while read LINE
do
	users_checked=$((users_checked + 1))
	echo $users_checked > sf_users_checked
	#if there is a Backup
	if [ $( ls -l /srv/sftp | awk '{print $3}' | grep -o $LINE | wc -l) -gt 0 ]; then
	#Are there multiple dates? If yes, skip to next iteration of while loop
		if [ $( ls -l /srv/sftp | awk '{print $3}' | grep -o $LINE | wc -l) -gt 1 ]; then
			echo "$LINE" >> sf_having_multiple_users
			continue
	#Calculate epoch from last_backup
		else
			folder=$(ls -l /srv/sftp | grep $LINE | awk '{print $9}')
            directory="/srv/sftp/"
			last_backup=$( stat --format %Y $(ls -t $(find $directory$folder -type f) | head -n 1) )
		fi
	#Calculate Delta between now and last_backup
		delta=`expr $now - $last_backup`
	#Transform 3 weeks in seconds and compare against delta 3weeks=1814400
		if [ $delta -gt $timespan ]; then
			echo "$LINE" >> sf_old_backup_users
			old_backup_counter=$((old_backup_counter + 1))
			echo $old_backup_counter > sf_old_backup_counter
		else
			active_backup_counter=$((active_backup_counter + 1))
			echo $active_backup_counter > sf_active_backup_counter
		fi
	else
		echo "$LINE" >> sf_not_having_backup_users
		not_having_counter=$((not_having_counter + 1))
		echo $not_having_counter > sf_not_having_counter
	fi
done
sf_users_checked=$(cat sf_users_checked)
sf_active_backup_counter=$(cat sf_active_backup_counter)
sf_old_backup_counter=$(cat sf_old_backup_counter)
sf_not_having_counter=$(cat sf_not_having_counter)

total_users_checked=`expr $tm_users_checked + $sf_users_checked`
#echo "total users checked: $total_users_checked = $tm_users_checked + $sf_users_checked" 

total_active_backup_counter=`expr $tm_active_backup_counter + $sf_active_backup_counter`
#echo "total active backup counter: $total_active_backup_counter = $tm_active_backup_counter + $sf_active_backup_counter"

total_old_backup_counter=`expr $tm_old_backup_counter + $sf_old_backup_counter`
#echo "total old backup counter: $total_old_backup_counter"
total_not_having_counter=`expr $tm_not_having_counter + $sf_not_having_counter`
#echo "total not having counter : $total_not_having_counter"
total_backup_succesful_quota=$(bc <<< "scale=1;$total_active_backup_counter/$total_users_checked" | awk '{printf "%f", $0}')
#echo "total backup Successful quota: $total_backup_succesful_quota"

infotxt="\nTotal Users Checked: $total_users_checked 
Active Backups found: $total_active_backup_counter
Outdated Backups found: $(cat tm_old_backup_users sf_old_backup_users | tr "\n" " ")
Users not having backups: $(cat tm_not_having_backup_users sf_not_having_backup_users | tr "\n" " ")
Backups Successful Quota: $total_backup_succesful_quota	"
#echo -e "$infotxt" >> check_backupstate.log

#Reporting for Icinga
if [ $(echo "$total_backup_succesful_quota < $threshold_warn" | bc -l) -eq 1 ] && [ $(echo "$total_backup_succesful_quota > $threshold_crit" | bc -l) -eq 1 ]; then
	status=1
	statustxt=WARN
elif [ $(echo "$total_backup_succesful_quota < $threshold_warn" | bc -l) -eq 1 ] && [ $(echo "$total_backup_succesful_quota < $threshold_crit" | bc -l) -eq 1 ]; then
	status=2
	statustxt=CRITICAL
else
	status=0
	statustxt=OK
fi
echo -e "Team Backup is $statustxt $infotxt"

#Cleanup
rm tm_users_checked tm_active_backup_counter tm_old_backup_counter tm_not_having_counter sf_users_checked sf_active_backup_counter sf_old_backup_counter sf_not_having_counter passwd_out total_backup_succesful_quota 	total_active_backup_counter	total_not_having_counter total_old_backup_counter total_users_checked tm_old_backup_users tm_not_having_backup_users tm_having_multiple_users sf_old_backup_users sf_not_having_backup_users sf_having_multiple_users
exit $status

