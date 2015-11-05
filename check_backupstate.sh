#!/bin/bash
#Configuration
timespan=1814400
threshold_warn=0.75
threshold_crit=0.25
now=$(date +%s)
#cd /home/nagios
#Touch is not enough -> echo them with zeros
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

#Check TimeMachine in /srv/backup
echo -e "\n$(date +'%a %d %b - %T') Check Timemachine Backup Success"

cat /etc/passwd | cut -f1 -d : > passwd_out
grep -Fxv -f blacklist passwd_out | while read LINE
do
	#echo "$(date +'%a %d %b - %T') Checking Backup Status for $LINE " >> check_tmstate.log
	users_checked=$((users_checked + 1))
	echo $users_checked > tm_users_checked
	#if there is a Backup
	if [ $( ls -l /srv/backup | grep -o $LINE | wc -l) -gt 0 ]; then
	#Are there multiple dates? If yes, skip to next iteration of while loop
		if [ $(ls --full-time /srv/backup | grep $LINE | awk '{print $6}' | wc -l) -gt 1 ]; then
			echo "$(date +'%a %d %b - %T') $LINE is having multiple backup folders"
			continue
	#Calculate epoch from last_backup
		else
			last_backup=$(date -d $(ls --full-time /srv/backup | grep $LINE | awk '{print $6}') +%s)
		fi
	#Calculate Delta between now and last_backup
		delta=`expr $now - $last_backup`
	#Transform 3 weeks in seconds and compare against delta 3weeks=1814400
		if [ $delta -gt $timespan ]; then
			echo "$(date +'%a %d %b - %T') $LINE is having old backup"
			old_backup_counter=$((old_backup_counter + 1))
			echo $old_backup_counter > tm_old_backup_counter
		else
			echo "$(date +'%a %d %b - %T') $LINE is having active Backup"
			active_backup_counter=$((active_backup_counter + 1))
			echo $active_backup_counter > tm_active_backup_counter
		fi
	else
		echo "$(date +'%a %d %b - %T') $LINE is not having a Backup"
		not_having_counter=$((not_having_counter + 1))
		echo $not_having_counter > tm_not_having_counter
	fi
done

#Store TM Performance Indicators
tm_users_checked=$(cat tm_users_checked)
tm_active_backup_counter=$(cat tm_active_backup_counter)
tm_old_backup_counter=$(cat tm_old_backup_counter)
tm_not_having_counter=$(cat tm_not_having_counter)

#----------------------------------------------------------------------------------------------------------
echo -e "\n$(date +'%a %d %b - %T') Check SFTP Backup Success"
grep -Fx -f blacklist linux_users | while read LINE
do
	#echo "$(date +'%a %d %b - %T') Checking Backup Status for $LINE " >> check_tmstate.log
	users_checked=$((users_checked + 1))
	echo $users_checked > sf_users_checked
	#if there is a Backup
	if [ $( ls -l /srv/sftp | grep -o $LINE | wc -l) -gt 0 ]; then
	#Are there multiple dates? If yes, skip to next iteration of while loop
		if [ $(ls --full-time /srv/sftp | grep $LINE | awk '{print $6}' | wc -l) -gt 1 ]; then
			echo "$(date +'%a %d %b - %T') $LINE is having multiple backup folders"
			continue
	#Calculate epoch from last_backup
		else
			last_backup=$(date -d $(ls --full-time /srv/sftp | grep $LINE | awk '{print $6}') +%s)
		fi
	#Calculate Delta between now and last_backup
		delta=`expr $now - $last_backup`
	#Transform 3 weeks in seconds and compare against delta 3weeks=1814400
		if [ $delta -gt $timespan ]; then
			echo "$(date +'%a %d %b - %T') $LINE is having old backup" 
			old_backup_counter=$((old_backup_counter + 1))
			echo $old_backup_counter > sf_old_backup_counter
		else
			echo "$(date +'%a %d %b - %T') $LINE is having active Backup" 
			active_backup_counter=$((active_backup_counter + 1))
			echo $active_backup_counter > sf_active_backup_counter
		fi
	else
		echo "$(date +'%a %d %b - %T') $LINE is not having a Backup"
		not_having_counter=$((not_having_counter + 1))
		echo $not_having_counter > sf_not_having_counter
	fi
done
sf_users_checked=$(cat sf_users_checked)
sf_active_backup_counter=$(cat sf_active_backup_counter)
sf_old_backup_counter=$(cat sf_old_backup_counter)
sf_not_having_counter=$(cat sf_not_having_counter)

total_users_checked=`expr $tm_users_checked + $sf_users_checked`
echo "total users checked: $total_users_checked = $tm_users_checked + $sf_users_checked"

total_active_backup_counter=`expr $tm_active_backup_counter + $sf_active_backup_counter`
echo "total active backup counter: $total_active_backup_counter = $tm_active_backup_counter + $sf_active_backup_counter"
#! bangs because sf_active_backup_counter is null but not zero

total_old_backup_counter=`expr $tm_old_backup_counter + $sf_old_backup_counter`
echo "total old backup counter: $total_old_backup_counter"
total_not_having_counter=`expr $tm_not_having_counter + $sf_not_having_counter`
echo "total not having counter : $total_not_having_counter"
total_backup_succesful_quota=$(bc <<< "scale=1;$total_active_backup_counter/$total_users_checked" | awk '{printf "%f", $0}')
echo "total backup Successful quota: $total_backup_succesful_quota"

echo "Write into Logfile"
infotxt="\nTotal Users Checked: $total_users_checked \nActive Backups found: $total_active_backup_counter \nOutdated Backups found: $total_old_backup_counter \nUsers not having backups: $total_not_having_counter \nBackups Successful Quota: $total_backup_succesful_quota\nFor more information see /home/nagios/check_backupstate.log"
echo -e "$infotxt" >> check_backupstate.log

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
echo -e "Backup is $statustxt $infotxt"

#Cleanup
rm tm_users_checked tm_active_backup_counter tm_old_backup_counter tm_not_having_counter sf_users_checked sf_active_backup_counter sf_old_backup_counter sf_not_having_counter passwd_out total_backup_succesful_quota
exit $status

