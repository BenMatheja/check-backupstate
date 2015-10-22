#!/bin/bash
#Configuration
timespan=1814400
threshold_warn=0.75
threshold_crit=0.25
now=$(date +%s)
#cd /home/nagios
touch tm_users_checked tm_active_backup_counter tm_old_backup_counter tm_not_having_counter sf_users_checked sf_active_backup_counter sf_old_backup_counter sf_not_having_counter
#Check TimeMachine in /srv/backup
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

#Store TM Performance Indicators
tm_users_checked=$(cat tm_users_checked)
tm_active_backup_counter=$(cat tm_active_backup_counter)
tm_old_backup_counter=$(cat tm_old_backup_counter)
tm_not_having_counter=$(cat tm_not_having_counter)

#Check SFTP in /srv/sftp
echo -e "\n$(date +'%a %d %b - %T') Check SFTP Backup Success" >> check_backupstate.log
grep -Fxv -f linux_users blacklist | while read LINE
do
	#echo "$(date +'%a %d %b - %T') Checking Backup Status for $LINE " >> check_tmstate.log
	users_checked=$((users_checked + 1))
	echo $users_checked > sf_users_checked
	#if there is a Backup
	if [ $( ls -l /srv/sftp | grep -o $LINE | wc -l) -gt 0 ]; then
	#Are there multiple dates? If yes, skip to next iteration of while loop
		if [ $(ls --full-time /srv/sftp | grep $LINE | awk '{print $6}' | wc -l) -gt 1 ]; then
			echo "$(date +'%a %d %b - %T') $LINE is having multiple backup folders" >> check_backupstate.log
			continue
	#Calculate epoch from last_backup
		else
			last_backup=$(date -d $(ls --full-time /srv/sftp | grep $LINE | awk '{print $6}') +%s)
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
#Store SFTP Performance Indicators
sf_users_checked=$(cat sf_users_checked)
sf_active_backup_counter=$(cat sf_active_backup_counter)
sf_old_backup_counter=$(cat sf_old_backup_counter)
sf_not_having_counter=$(cat sf_not_having_counter)

#Compute Result
total_users_checked=`expr $tm_users_checked + $sf_users_checked`
total_active_backup_counter=`expr $tm_active_backup_counter + $sf_active_backup_counter`
total_old_backup_counter=`expr $tm_old_backup_counter + $sf_old_backup_counter`
total_not_having_counter=`expr $tm_not_having_counter + $sf_not_having_counter`
total_backup_succesful_quota=$(bc <<< "scale=2;$(cat total_active_backup_counter)/$(cat total_users_checked)" | awk '{printf "%f", $0}')
#Cleanup
rm tm_users_checked tm_active_backup_counter tm_old_backup_counter tm_not_having_counter sf_users_checked sf_active_backup_counter sf_old_backup_counter sf_not_having_counter passwd_out

