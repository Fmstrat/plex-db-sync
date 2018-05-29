#!/bin/bash

function echoD {
	echo "[`date`] ${@}"
}

function echoDN {
	echo -n "[`date`] ${@}"
}

V_S1_DB_PATH=""; if [ -n "${S1_DB_PATH}" ]; then V_S1_DB_PATH="${S1_DB_PATH}"; fi
V_S2_DB_PATH=""; if [ -n "${S2_DB_PATH}" ]; then V_S2_DB_PATH="${S2_DB_PATH}"; fi
V_BACKUP="false"; if [ -n "${BACKUP}" ]; then V_BACKUP="${BACKUP}"; fi
V_DEBUG="false"; if [ -n "${DEBUG}" ]; then V_DEBUG="${DEBUG}"; fi
V_DRYRUN="false"; if [ -n "${DRYRUN}" ]; then V_DRYRUN="${DRYRUN}"; fi
V_TMPFOLDER="/tmp/plex-db-sync"; if [ -n "${TMPFOLDER}" ]; then V_TMPFOLDER="${TMPFOLDER}"; fi
V_CRON="0 4 * * *"; if [ -n "${CRON}" ]; then V_CRON="${CRON}"; fi

# Mount any needed volumes
if [ -n "${S1_SSH_KEY}" ] && [ -n "${S1_SSH_PORT}" ] && [ -n "${S1_SSH_USER}" ] && [ -n "${S1_SSH_HOST}" ] && [ -n "${S1_SSH_PATH}" ]; then
	echoDN "Mounting sshfs for server 1... "
	mkdir -p /mnt/S1
	eval sshfs -o allow_other,StrictHostKeyChecking=no,IdentityFile="${S1_SSH_KEY}" -p ${S1_SSH_PORT} ${S1_SSH_USER}@${S1_SSH_HOST}:"${S1_SSH_PATH}" /mnt/S1
	V_S1_DB_PATH="/mnt/S1"
	echo "Done"
fi
if [ -n "${S2_SSH_KEY}" ] && [ -n "${S2_SSH_PORT}" ] && [ -n "${S2_SSH_USER}" ] && [ -n "${S2_SSH_HOST}" ] && [ -n "${S2_SSH_PATH}" ]; then
	echoDN "Mounting sshfs for server 2... "
	mkdir -p /mnt/S2
	eval sshfs -o allow_other,StrictHostKeyChecking=no,IdentityFile="${S2_SSH_KEY}" -p ${S2_SSH_PORT} ${S2_SSH_USER}@${S2_SSH_HOST}:"${S2_SSH_PATH}" /mnt/S2
	V_S2_DB_PATH="/mnt/S2"
	echo "Done"
fi

# Set up cron
echoD "Setting up cron."
echo -e "${V_CRON} /plex-db-sync --dry-run \x22${V_DRYRUN}\x22 --backup \x22${V_BACKUP}\x22 --debug \x22${V_DEBUG}\x22 --tmp-folder \x22${V_TMPFOLDER}\x22 --plex-db-1 \x22${V_S1_DB_PATH}/com.plexapp.plugins.library.db\x22 --plex-start-1 \x22${S1_START}\x22 --plex-stop-1 \x22${S1_STOP}\x22 --plex-db-2 \x22${V_S2_DB_PATH}/com.plexapp.plugins.library.db\x22 --plex-start-2 \x22${S2_START}\x22 --plex-stop-2 \x22${S2_STOP}\x22 --ignore-accounts \x22${IGNOREACCOUNTS}\x22" > /crontab.txt
chmod 0644 /crontab.txt
touch /var/log/cron.log
crontab /crontab.txt
crond -f -l 8


# Loop to run sync
#while [ 1 -eq 1 ]; do
	#eval sleep ${V_INTERVAL}
#done;
