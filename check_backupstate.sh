#!/bin/bash
#Configuration
timespan=1814400
threshold_warn=0.75
threshold_crit=0.25
now=$(date +%s)

#cd /home/nagios

#Check TimeMachine in /var/srv
echo -e "\n$(date +'%a %d %b - %T') Check Timemachine Backup Success" >> check_backupstate.log

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
			echo "$(date +'%a %d %b - %T') $LINE is having multiple backup folders" >> check_backupstate.log
			continue
	#Calculate epoch from last_backup
		else
			last_backup=$(date -d $(ls --full-time /srv/backup | grep $LINE | awk '{print $6}') +%s)
		fi
	#Calculate Delta between now and last_backup
		delta=`expr $now - $last_backup`
	#Transform 3 weeks in seconds and compare against delta 3weeks=1814400
		if [ $delta -gt $timespan ]; then
			echo "$(date +'%a %d %b - %T') $LINE is having old backup" >> check_backupstate.log
			old_backup_counter=$((old_backup_counter + 1))
			echo $old_backup_counter > tm_old_backup_counter
		else
			echo "$(date +'%a %d %b - %T') $LINE is having active Backup" >> check_backupstate.log
			active_backup_counter=$((active_backup_counter + 1))
			echo $active_backup_counter > tm_active_backup_counter
		fi
	else
		echo "$(date +'%a %d %b - %T') $LINE is not having a Backup" >> check_backupstate.log
		not_having_counter=$((not_having_counter + 1))
		echo $not_having_counter > tm_not_having_counter
	fi
done

#Calculate Performance Indicators
users_checked=$(cat tm_users_checked)
active_backup_counter=$(cat tm_active_backup_counter)
old_backup_counter=$(cat tm_old_backup_counter)
not_having_counter=$(cat tm_not_having_counter)
#backup_succesfull_quota=$(bc <<< "scale=2;$(cat active_backup_counter)/$(cat users_checked)" | awk '{printf "%f", $0}')

