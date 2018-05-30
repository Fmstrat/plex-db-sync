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

echo "#!/bin/bash" > /cron-script
echo "" >> /cron-script

# Set up cron script
if [ -n "${S1_SSH_KEY}" ] && [ -n "${S1_SSH_PORT}" ] && [ -n "${S1_SSH_USER}" ] && [ -n "${S1_SSH_HOST}" ] && [ -n "${S1_SSH_PATH}" ]; then
	mkdir -p /mnt/S1
	V_S1_DB_PATH="/mnt/S1"
	echo -e "echo \x22[\`date\`] Mounting sshfs for server 1...\x22" >> /cron-script
	echo -e "sshfs -o allow_other,cache=no,no_readahead,noauto_cache,StrictHostKeyChecking=no,IdentityFile=\x22${S1_SSH_KEY}\x22 -p ${S1_SSH_PORT} ${S1_SSH_USER}@${S1_SSH_HOST}:\x22${S1_SSH_PATH}\x22 /mnt/S1" >> /cron-script
fi
if [ -n "${S2_SSH_KEY}" ] && [ -n "${S2_SSH_PORT}" ] && [ -n "${S2_SSH_USER}" ] && [ -n "${S2_SSH_HOST}" ] && [ -n "${S2_SSH_PATH}" ]; then
	mkdir -p /mnt/S2
	V_S2_DB_PATH="/mnt/S2"
	echo -e "echo \x22[\`date\`] Mounting sshfs for server 2...\x22" >> /cron-script
	echo -e "sshfs -o allow_other,cache=no,no_readahead,noauto_cache,StrictHostKeyChecking=no,IdentityFile=\x22${S2_SSH_KEY}\x22 -p ${S2_SSH_PORT} ${S2_SSH_USER}@${S2_SSH_HOST}:\x22${S2_SSH_PATH}\x22 /mnt/S2" >> /cron-script
fi
echo -e "/plex-db-sync --dry-run \x22${V_DRYRUN}\x22 --backup \x22${V_BACKUP}\x22 --debug \x22${V_DEBUG}\x22 --tmp-folder \x22${V_TMPFOLDER}\x22 --plex-db-1 \x22${V_S1_DB_PATH}/com.plexapp.plugins.library.db\x22 --plex-start-1 \x22${S1_START}\x22 --plex-stop-1 \x22${S1_STOP}\x22 --plex-db-2 \x22${V_S2_DB_PATH}/com.plexapp.plugins.library.db\x22 --plex-start-2 \x22${S2_START}\x22 --plex-stop-2 \x22${S2_STOP}\x22 --ignore-accounts \x22${IGNOREACCOUNTS}\x22" >> /cron-script
if [ -n "${S1_SSH_KEY}" ] && [ -n "${S1_SSH_PORT}" ] && [ -n "${S1_SSH_USER}" ] && [ -n "${S1_SSH_HOST}" ] && [ -n "${S1_SSH_PATH}" ]; then
	echo "umount /mnt/S1" >> /cron-script
fi
if [ -n "${S2_SSH_KEY}" ] && [ -n "${S2_SSH_PORT}" ] && [ -n "${S2_SSH_USER}" ] && [ -n "${S2_SSH_HOST}" ] && [ -n "${S2_SSH_PATH}" ]; then
	echo "umount /mnt/S2" >> /cron-script
fi
chmod +x /cron-script

if [ "${INITIALRUN}" == "true" ]; then
	/cron-script
fi

# Set up cron
echoD "Setting up cron."
echo -e "${V_CRON} /cron-script" > /crontab.txt
chmod 0644 /crontab.txt
touch /var/log/cron.log
crontab /crontab.txt
crond -f -l 8
