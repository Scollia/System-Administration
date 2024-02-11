#!/bin/bash

###########################
####### LOAD CONFIG #######
###########################

while [ $# -gt 0 ]; do
  case $1 in
    -c)
      if [ -r "$2" ]; then
        CONFIG_FILE_PATH="$2"
        shift 2
      else
        ${ECHO} "Unreadable config file \"$2\"" 1>&2
        exit 1
      fi
      ;;
    *)
      ${ECHO} "Unknown Option \"$1\"" 1>&2
      exit 2
      ;;
  esac
done

if [ -z $CONFIG_FILE_PATH ] ; then
# полный путь до скрипта
    ABSOLUTE_FILENAME=`readlink -e "$0"`
    SCRIPTPATH=${ABSOLUTE_FILENAME%/*}
    CONFIG_FILE_PATH="${SCRIPTPATH}/pg_backup.config"
fi

if [ ! -r ${CONFIG_FILE_PATH} ] ; then
    echo "Could not load config file from ${CONFIG_FILE_PATH}" 1>&2
    exit 1
else
  source "${CONFIG_FILE_PATH}"
fi

###########################
#### PRE-BACKUP CHECKS ####
###########################

# Make sure we're running as the required backup user
if [ "$BACKUP_USER" != "" -a "$(id -un)" != "$BACKUP_USER" ]; then
  echo "This script must be run as $BACKUP_USER. Exiting." 1>&2
  exit 1;
fi;

###########################
### INITIALISE DEFAULTS ###
###########################

if [ ! $USERNAME ]; then
  USERNAME="postgres"
fi;

###########################
#### START THE BACKUPS ####
###########################

function perform_backups()
{
#  PREFIX=$1
#  FINAL_BACKUP_DIR=$BACKUP_DIR"$SUFFIX/`date +\%Y-\%m-\%d`/"

  echo "Making backup directory in $FINAL_BACKUP_DIR"

  if ! mkdir -p $BACKUP_DIR; then
    echo "Cannot create backup directory in $BACKUP_DIR. Go and fix it!" 1>&2
    exit 1;
  fi;

  if $NET_BACKUP = "yes" then
# umount //10.0.210.131/backup
# mount -t cifs //10.0.210.131/backup /sql_data/backup -o username=writeuser,password=writeuser,iocharset=utf8,file_mode=0777,dir_mode=0777
    umount $BACKUP_DIR
    if ! mount -t cifs $NET_BACKUP_DIR $BACKUP_DIR -o username=$NET_USER,password=$NET_PASSWD,iocharset=utf8,file_mode=0777,dir_mode=0777 then
      echo "Cannot mount backup directory $NET_BACKUP_DIR in $BACKUP_DIR. Go and fix it!" 1>&2
      exit 1;
    fi;
  fi;

  #######################
  ### GLOBALS BACKUPS ###
  #######################

  echo -e "\n\nPerforming globals backup"
  echo -e "--------------------------------------------\n"

  if [ $ENABLE_GLOBALS_BACKUPS = "yes" ]
  then
      echo "Globals backup"

      if ! pg_dumpall -g -U "$USERNAME" | gzip > $BACKUP_DIR"globals".sql.gz.in_progress; then
          echo "[!!ERROR!!] Failed to produce globals backup" 1>&2
      else
          mv $BACKUP_DIR"globals".sql.gz.in_progress $BACKUP_DIR"globals".sql.gz
      fi
  else
    echo "None"
  fi

  ###########################
  ### SCHEMA-ONLY BACKUPS ###
  ###########################

  for SCHEMA_ONLY_DB in ${SCHEMA_ONLY_LIST//,/ }
  do
    SCHEMA_ONLY_CLAUSE="$SCHEMA_ONLY_CLAUSE or datname ~ '$SCHEMA_ONLY_DB'"
  done

  SCHEMA_ONLY_QUERY="select datname from pg_database where false $SCHEMA_ONLY_CLAUSE order by datname;"

  echo -e "\n\nPerforming schema-only backups"
  echo -e "--------------------------------------------\n"

  SCHEMA_ONLY_DB_LIST=`psql -U "$USERNAME" -At -c "$SCHEMA_ONLY_QUERY" postgres`

  echo -e "The following databases were matched for schema-only backup:\n${SCHEMA_ONLY_DB_LIST}\n"

  for DATABASE in $SCHEMA_ONLY_DB_LIST
  do
    echo "Schema-only backup of $DATABASE"

    if ! pg_dump -Fp -s -U "$USERNAME" "$DATABASE" | gzip > $BACKUP_DIR"$DATABASE"_SCHEMA.sql.gz.in_progress; then
      echo "[!!ERROR!!] Failed to backup database schema of $DATABASE" 1>&2
    else
      mv $BACKUP_DIR"$DATABASE"_SCHEMA.sql.gz.in_progress $BACKUP_DIR"$DATABASE"_SCHEMA.sql.gz
    fi
  done


  ###########################
  ###### FULL BACKUPS #######
  ###########################

  for SCHEMA_ONLY_DB in ${SCHEMA_ONLY_LIST//,/ }
  do
    EXCLUDE_SCHEMA_ONLY_CLAUSE="$EXCLUDE_SCHEMA_ONLY_CLAUSE and datname !~ '$SCHEMA_ONLY_DB'"
  done

  FULL_BACKUP_QUERY="select datname from pg_database where not datistemplate and datallowconn $EXCLUDE_SCHEMA_ONLY_CLAUSE order by datname;"

  echo -e "\n\nPerforming full backups"
  echo -e "--------------------------------------------\n"

  for DATABASE in `psql -U "$USERNAME" -At -c "$FULL_BACKUP_QUERY" postgres`
  do
    if [ $ENABLE_PLAIN_BACKUPS = "yes" ]
    then
      echo "Plain backup of $DATABASE"

      if ! pg_dump -Fp -U "$USERNAME" "$DATABASE" | gzip > $FINAL_BACKUP_DIR"$DATABASE".sql.gz.in_progress; then
        echo "[!!ERROR!!] Failed to produce plain backup database $DATABASE" 1>&2
      else
        mv $FINAL_BACKUP_DIR"$DATABASE".sql.gz.in_progress $FINAL_BACKUP_DIR"$DATABASE".sql.gz
      fi
    fi

    if [ $ENABLE_CUSTOM_BACKUPS = "yes" ]
    then
      echo "Custom backup of $DATABASE"

      if ! pg_dump -Fc -U "$USERNAME" "$DATABASE" -f $FINAL_BACKUP_DIR"$DATABASE".custom.in_progress; then
        echo "[!!ERROR!!] Failed to produce custom backup database $DATABASE"
      else
        mv $FINAL_BACKUP_DIR"$DATABASE".custom.in_progress $FINAL_BACKUP_DIR"$DATABASE".custom
      fi
    fi

  done
  echo -e "\nAll database backups complete!"
}

#
BACKUP_TIMECODE = `date +\%Y-\%m-\%d`

# MONTHLY BACKUPS

DAY_OF_MONTH=`date +%d`

if [ $DAY_OF_MONTH -eq 1 ];
then
  # Delete all expired monthly directories
  find $BACKUP_DIR -maxdepth 1 -name "*-monthly" -exec rm -rf '{}' ';'

  perform_backups "-monthly"

  exit 0;
fi

# WEEKLY BACKUPS

DAY_OF_WEEK=`date +%u` #1-7 (Monday-Sunday)
EXPIRED_DAYS=`expr $((($WEEKS_TO_KEEP * 7) + 1))`

if [ $DAY_OF_WEEK = $DAY_OF_WEEK_TO_KEEP ];
then
  # Delete all expired weekly directories
  find $BACKUP_DIR -maxdepth 1 -mtime +$EXPIRED_DAYS -name "*-weekly" -exec rm -rf '{}' ';'

  perform_backups "-weekly"

  exit 0;
fi

# DAILY BACKUPS

# Delete daily backups 7 days old or more
find $BACKUP_DIR -maxdepth 1 -mtime +$DAYS_TO_KEEP -name "*-daily" -exec rm -rf '{}' ';'
