Check Backup State
###################
Check Backup Status for employees by parsing folders last modified date
traverses /srv/backup and /srv/sftp

using the blacklist file, for all users not obliged to do timemachine backups (system users as well)
using the linux_users file, for all users who are obliged to do sftp backups

reports into check_backupstate.log
