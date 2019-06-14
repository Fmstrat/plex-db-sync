#!/bin/bash

ARGC=$#
ARGV=("$@")
COUNT1=0
COUNT2=0

function sqlite_query() {
	if [ ! -n "$1" ];then
		return 1
	fi
	DB=$1
	QUERY=$2
	sqlite3 "$DB" "$QUERY" -line -nullvalue "<<NULLSTR>>"
}

sqlite_read_line () {
    local IFS=" \= "
    read COL DATA
    local ret=$?
    COL_NAME=${COL// /}
    return $ret
}

function sqlite_create_fetch_array() {
	result=$(sqlite_query "$1" "$2")
	if [[ $? -eq 1 ]]; then
		return 1
	fi
	num_rows=0
	unset rows
	declare -Ag rows
	if [[ $result ]]; then
		while sqlite_read_line; do
			if [[ ! $COL_NAME ]];then
				((num_rows=num_rows+1))
			fi
	       	rows[$num_rows,"$COL_NAME"]="$DATA"
		done <<< "$result"
		((num_rows=num_rows+1))
	fi
}

function echoD {
	echo "[`date`] ${@}"
}

function echoDN {
	echo -n "[`date`] ${@}"
}

function sql() {
	if [ "${DEBUG}" == "true" ]; then
		echoD "-=-: $2"
	fi
	sqlite_create_fetch_array "$1" "$2"
}

function setnull() {
	tmpvar="'${1}'"
	if [ "$tmpvar" == "'<<NULLSTR>>'" ]; then
		tmpvar="null"
	fi
	echo $tmpvar
}

function initSql() {
	if [ -f "${PLEXF1}" ]; then
		rm -f "${PLEXF1}"
	fi
	touch "${PLEXF1}"
	if [ -f "${PLEXF2}" ]; then
		rm -f "${PLEXF2}"
	fi
	touch "${PLEXF2}"
}

function echoSql() {
	if [ "${DEBUG}" == "true" ]; then
		echoD "${1}: ${2}"
	fi
	echo "${2}" >> "${1}"
}

function checkDependencies() {
	if [ -z "$(which sqlite3)" ]; then
		echoD "Missing dependency: sqlite3"
		exit
	fi
	if [ -z "$(which sshfs)" ]; then
		echoD "Missing dependency: sshfs"
		exit
	fi
}

function checkForDBs() {
	if [ ! -f "$PLEXDB1" ]; then
		echoD "Server 1 DB not found"
		exit
	fi
	if [ ! -f "$PLEXDB2" ]; then
		echoD "Server 2 DB not found"
		exit
	fi
	if [ "${NOCOMPAREDB}" == "false" ]; then
		VPLEXDB1=$(echo "select version from schema_migrations order by version desc limit 1;" | sqlite3 "${PLEXDB1}")
		VPLEXDB2=$(echo "select version from schema_migrations order by version desc limit 1;" | sqlite3 "${PLEXDB2}")
		if [ "${DEBUG}" == "true" ]; then
			echoD "version db1: ${VPLEXDB1}  db2: ${VPLEXDB2}"
		fi
		if [ "${VPLEXDB1}" != "${VPLEXDB2}" ]; then
			echoD "Versions of plex databases not equal"
			exit
		fi
	fi
}

function initFS() {
	if [ ! -d "$TMPFOLDER" ]; then
		mkdir -p "$TMPFOLDER"
	else
		if [ -n "${TMPFOLDER}" ]; then
			rm -rf "${TMPFOLDER}/"*
		fi
	fi
	MOUNTED=$(mount |grep ramfs |grep "${TMPFOLDER}")
	if [ -z "$MOUNTED" ]; then
		mount -t ramfs ramfs "$TMPFOLDER"
	fi
}

function closeFS() {
	if [ -n "${TMPFOLDER}" ]; then
		rm -rf "${TMPFOLDER}/"*
	fi
	MOUNTED=$(mount |grep ramfs |grep "${TMPFOLDER}")
	if [ -n "$MOUNTED" ]; then
		umount "${TMPFOLDER}"
	fi
}

function getIgnore() {
	IGNORESTR=""
	if [ -n "$1" ]; then
		OLDIFS=$IFS
		IFS=","
		for ACCOUNT in $1; do
			if [ -z "$IGNORESTR" ]; then
				IGNORESTR="${IGNORESTR}lower('${ACCOUNT}')"
			else
				IGNORESTR="${IGNORESTR},lower('${ACCOUNT}')"
			fi
		done
		IGNORESTR="${IGNORESTR},''"
		IFS=$OLDIFS
	else
		IGNORESTR='';
	fi
	echo $IGNORESTR
}

function createTmpDB() {
	TablesTmpDB=(metadata_item_settings metadata_items taggings tags)
	for TableTmpDB in ${TablesTmpDB[*]}
	do
		sqlite3 "${PLEXDB1}" "select sql from sqlite_master where name = '${TableTmpDB}'" | sed -e "s,${TableTmpDB},${TableTmpDB}1,g" | sqlite3 "${TMPDB}"
		sqlite3 "${PLEXDB1}" "select sql from sqlite_master where name = '${TableTmpDB}'" | sed -e "s,${TableTmpDB},${TableTmpDB}2,g" | sqlite3 "${TMPDB}"
	done
	echo "attach '${PLEXDB1}' as plexdb; attach '${TMPDB}' as tmpdb; insert into tmpdb.metadata_item_settings1 select * from plexdb.metadata_item_settings; insert into tmpdb.metadata_items1 select * from plexdb.metadata_items; insert into tmpdb.taggings1 select * from plexdb.taggings; insert into tmpdb.tags1 select * from plexdb.tags;" | sqlite3
	echo "attach '${PLEXDB2}' as plexdb; attach '${TMPDB}' as tmpdb; insert into tmpdb.metadata_item_settings2 select * from plexdb.metadata_item_settings; insert into tmpdb.metadata_items2 select * from plexdb.metadata_items; insert into tmpdb.taggings2 select * from plexdb.taggings; insert into tmpdb.tags2 select * from plexdb.tags;" | sqlite3
}

function processTags() {
	# Apply Source and Destinate DBs
	if [ "${1}" == "1" ]; then
		S=1
		D=2
	else
		S=2
		D=1
	fi
	# Only handling "Share" tags of type 11 right now
	# First, let's make sure that any tags needed on the server
	sql "${TMPDB}" "select distinct t${S}.* from taggings${S} ts${S}, tags${S} t${S}, metadata_items${S} m${S} where ts${S}.tag_id=t${S}.id and ts${S}.metadata_item_id=m${S}.id and t${S}.tag_type=11 and m${S}.guid in (select guid from metadata_items${D}) and t${S}.tag not in (select tag from tags${D});"
	for (( i = 0; i < num_rows; i++ )); do
		# Now each one of these tags needs to be inserted.
		echoD "  - (${i}/${num_rows}) Adding tag ${rows[$i,"tag"]} on server ${D}"
		echoSql "${2}" "insert into tags (metadata_item_id, tag, tag_type, user_thumb_url, user_art_url, user_music_url, created_at, updated_at, tag_value, extra_data, key, parent_id) values (`setnull "${rows[$i,"metadata_item_id"]}"`, `setnull "${rows[$i,"tag"]}"`, `setnull "${rows[$i,"tag_type"]}"`, `setnull "${rows[$i,"user_thumb_url"]}"`, `setnull "${rows[$i,"user_art_url"]}"`, `setnull "${rows[$i,"user_music_url"]}"`, `setnull "${rows[$i,"created_at"]}"`, `setnull "${rows[$i,"updated_at"]}"`, `setnull "${rows[$i,"tag_value"]}"`, `setnull "${rows[$i,"extra_data"]}"`, `setnull "${rows[$i,"key"]}"`, `setnull "${rows[$i,"parent_id"]}"`);";
		if [ "${1}" == "1" ]; then
			(( COUNT2++ ));
		else
			(( COUNT1++ ));
		fi
	done
	# Now we can insert any taggings required
	sql "${TMPDB}" "select ts${S}.*, t${S}.tag, m${S}.guid from taggings${S} ts${S}, tags${S} t${S}, metadata_items${S} m${S} where ts${S}.tag_id=t${S}.id and ts${S}.metadata_item_id=m${S}.id and t${S}.tag_type=11 and m${S}.guid in (select guid from metadata_items${D}) and m${S}.guid not in (select distinct m${D}.guid from taggings${D} ts${D}, tags${D} t${D}, metadata_items${D} m${D} where ts${D}.tag_id=t${D}.id and ts${D}.metadata_item_id=m${D}.id and t${D}.tag_type=11 and t${D}.tag=t${S}.tag);"
	for (( i = 0; i < num_rows; i++ )); do
		echoD "  - (${i}/${num_rows}) Adding tag ${rows[$i,"tag"]} to ${rows[$i,"guid"]} on server ${D}"
		echoSql "${2}" "insert into taggings (metadata_item_id, tag_id, 'index', text, time_offset, end_time_offset, thumb_url, created_at, extra_data) select m.id as metadata_item_id, t.id as tag_id, `setnull "${rows[$i,"index"]}"`, `setnull "${rows[$i,"text"]}"`, `setnull "${rows[$i,"time_offset"]}"`, `setnull "${rows[$i,"end_time_offset"]}"`, `setnull "${rows[$i,"thumb_url"]}"`, `setnull "${rows[$i,"created_at"]}"`, `setnull "${rows[$i,"extra_data"]}"` from metadata_items m, tags t where m.guid='${rows[$i,"guid"]}' and t.tag='${rows[$i,"tag"]}';"
		if [ "${1}" == "1" ]; then
			(( COUNT2++ ));
		else
			(( COUNT1++ ));
		fi
	done
}

function processWatchedCommon() {
	sql "${TMPDB}" "select s1.guid, s1.id as id1, s1.updated_at as updated_at1, s1.view_count as view_count1, s1.last_viewed_at as last_viewed_at1, s1.view_offset as view_offset1, s1.changed_at as changed_at1, s2.id as id2, s2.updated_at as updated_at2, s2.view_count as view_count2, s2.last_viewed_at as last_viewed_at2, s2.view_offset as view_offset2, s2.changed_at as changed_at2 from metadata_item_settings1 s1, metadata_item_settings2 s2 where s1.guid=s2.guid and s1.account_id=s2.account_id and s1.account_id=${1} and (s1.view_count != s2.view_count or s1.last_viewed_at != s2.last_viewed_at or s1.view_offset != s2.view_offset or s1.changed_at != s2.changed_at);"
	for (( i = 0; i < num_rows; i++ )); do
		# Which record is newer?
		updated_at1_int=$(date -d "${rows[$i,"updated_at1"]}" +%s)
		updated_at2_int=$(date -d "${rows[$i,"updated_at2"]}" +%s)
		if [ ${updated_at1_int} -ge ${updated_at2_int} ] || [ ${rows[$i,"changed_at1"]} -ge ${rows[$i,"changed_at2"]} ]; then
			# Server 1 is newer
			echoD "    - (${i}/${num_rows}) Setting server 2 status for: ${rows[$i,"guid"]}"
			last_viewed_at=$(setnull "${rows[$i,"last_viewed_at1"]}")
			view_offset=$(setnull "${rows[$i,"view_offset1"]}")
			echoSql "${PLEXF2}" "update metadata_item_settings set updated_at='${rows[$i,"updated_at1"]}', view_count=${rows[$i,"view_count1"]}, last_viewed_at=${last_viewed_at}, view_offset=${view_offset}, changed_at=${rows[$i,"changed_at1"]} where id=${rows[$i,"id2"]};"
			((COUNT2++))
		else
			# Server 2 is newer
			echoD "    - (${i}/${num_rows}) Setting server 1 status for: ${rows[$i,"guid"]}"
			last_viewed_at=$(setnull "${rows[$i,"last_viewed_at2"]}")
			view_offset=$(setnull "${rows[$i,"view_offset2"]}")
			echoSql "${PLEXF1}" "update metadata_item_settings set updated_at='${rows[$i,"updated_at2"]}', view_count=${rows[$i,"view_count2"]}, last_viewed_at=${last_viewed_at}, view_offset=${view_offset}, changed_at=${rows[$i,"changed_at2"]} where id=${rows[$i,"id1"]};"
			(( COUNT1++ ));
		fi
	done
}

function processWatchedNew() {
	sql "${TMPDB}" "select * from metadata_item_settings${3} where guid in (select guid from metadata_items${4}) and guid not in (select guid from metadata_item_settings${4} where account_id=${1}) and account_id=${1};"
	for (( i = 0; i < num_rows; i++ )); do
		echoD "    - (${i}/${num_rows}) Setting server ${4} status for: ${rows[$i,"guid"]}"
		rating=$(setnull "${rows[$i,"rating"]}")
		view_offset=$(setnull "${rows[$i,"view_offset"]}")
		last_viewed_at=$(setnull "${rows[$i,"last_viewed_at"]}")
		skip_count=$(setnull "${rows[$i,"skip_count"]}")
		last_skipped_at=$(setnull "${rows[$i,"last_skipped_at"]}")
		extra_data=$(setnull "${rows[$i,"extra_data"]}")
		echoSql "${2}" "insert into metadata_item_settings (account_id, guid, rating, view_offset, view_count, last_viewed_at, created_at, updated_at, skip_count, last_skipped_at, changed_at, extra_data) values ('${1}', '${rows[$i,"guid"]}', ${rating}, ${view_offset}, '${rows[$i,"view_count"]}', ${last_viewed_at}, '${rows[$i,"created_at"]}', '${rows[$i,"updated_at"]}', ${skip_count}, ${last_skipped_at}, ${rows[$i,"changed_at"]}, ${extra_data});"
		if [ ${4} -eq 2 ]; then
			((COUNT2++))
		else
			((COUNT1++))
		fi
	done
}

function getConfig() {
	V=""
	for (( j=0; j<ARGC; j++ )); do
		if [ "${ARGV[j]}" == "${1}" ]; then
			V="${ARGV[j+1]}"
			break;
		fi
	done
	if [ -z "${V}" ]; then
		V="${2}"
	fi
	echo "${V}"
}

function checkRequired() {
	V=$(getConfig "${1}" "")
	if [ -z "${V}" ]; then
		echoD "Error: ${1} is a required flag"
		showUsage
		exit
	fi
}

function stopServers() {
	if [ -n "${PLEXSTOP1}" ]; then
		echoDN "Stopping Plex on Server 1... "
		eval ${PLEXSTOP1} 1> /dev/null 2>&1
		echo "Done"
	fi
	if [ -n "${PLEXSTOP2}" ]; then
		echoDN "Stopping Plex on Server 2... "
		eval ${PLEXSTOP2} 1> /dev/null 2>&1
		echo "Done"
	fi
	sleep 3
}

function startServers() {
	sleep 3
	if [ -n "${PLEXSTART1}" ]; then
		echoDN "Starting Plex on Server 1... "
		eval ${PLEXSTART1} 1> /dev/null 2>&1
		echo "Done"
	fi
	if [ -n "${PLEXSTART2}" ]; then
		echoDN "Starting Plex on Server 2... "
		eval ${PLEXSTART2} 1> /dev/null 2>&1
		echo "Done"
	fi
}

function updateServers() {
	if [ $COUNT1 -gt 0 ]; then
		if [ "${BACKUP}" == "true" ]; then
			runBackup "${PLEXDB1}"
		fi
		file2sql "${PLEXDB1}" "${PLEXF1}"
	fi
	if [ $COUNT2 -gt 0 ]; then
		if [ "${BACKUP}" == "true" ]; then
			runBackup "${PLEXDB2}"
		fi
		file2sql "${PLEXDB2}" "${PLEXF2}"
	fi
}

function file2sql() {
	if [ "$DRYRUN" == false ]; then
		echoD "Applying DB changes to ${1}..."
		sqlite3 "$1" < "$2"
	else
		echoD "(DRY RUN) Applying DB changes to ${1}..."
	fi
}

function runBackup() {
	echoD "Backing up ${1}..."
	cp -a "${1}" "${1}.dbsyc.bak"
}

function printConfig() {
	if [ "${DEBUG}" == "true" ]; then
		echoD "TMPFOLDER: ${TMPFOLDER}"
		echoD "DEBUG: ${DEBUG}"
		echoD "PLEXDB1: ${PLEXDB1}"
		echoD "PLEXDB2: ${PLEXDB2}"
		echoD "PLEXSTART1: ${PLEXSTART1}"
		echoD "PLEXSTOP1: ${PLEXSTOP1}"
		echoD "PLEXSTART2: ${PLEXSTART2}"
		echoD "PLEXSTOP2: ${PLEXSTOP2}"
		echoD "PLEXF1: ${PLEXF1}"
		echoD "PLEXF2: ${PLEXF2}"
		echoD "TMPDB: ${TMPDB}"
		echoD "IGNORE: ${IGNORE}"
		echoD "IGNORESTR: ${IGNORESTR}"
		echoD "BACKUP: ${BACKUP}"
	fi
}

function showUsage() {
	echoD "Usage: ./plex-db-sync.sh --dry-run <true/false> --backup <true/false> --debug <true/false> --nocomparedb <true/false> --plex-db-1 <path/to/database.db (r)> --plex-db-2 <path/to/database.db (r)> --plex-start-1 <command to start plex (r)> --plex-stop-1 <command to stop plex (r)> --plex-start-2 <command to start plex (r)> --plex-stop-2 <command to stop plex (r)> --ignore-accounts <Account1,Account2> --tmp-folder </tmp/plex-db-sync>"
}

function checkForNew() {
	#return 0
	UP1=$(echo "select updated_at from metadata_item_settings order by updated_at desc limit 1;" | sqlite3 "${PLEXDB1}")
	UP2=$(echo "select updated_at from metadata_item_settings order by updated_at desc limit 1;" | sqlite3 "${PLEXDB2}")
	if [ "$DEBUG" == "true" ]; then
		echoD "UP1: $UP1 - UP2: $UP2"
	fi
	if [ "${UP1}" != "${UP2}" ]; then
		return 0
	fi
	CH1=$(echo "select changed_at from metadata_item_settings order by changed_at desc limit 1;" | sqlite3 "${PLEXDB1}")
	CH2=$(echo "select changed_at from metadata_item_settings order by changed_at desc limit 1;" | sqlite3 "${PLEXDB2}")
	if [ "$DEBUG" == "true" ]; then
		echoD "CH1: $CH1 - CH2: $CH2"
	fi
	if [ "${CH1}" != "${CH2}" ]; then
		return 0
	fi
	return 1
}

echoD "Starting."
checkDependencies
TMPFOLDER=$(getConfig "--tmp-folder" "/tmp/plex-db-sync")
DEBUG=$(getConfig "--debug" "false")
BACKUP=$(getConfig "--backup" "false")
DRYRUN=$(getConfig "--dry-run" "false")
NOCOMPAREDB=$(getConfig "--nocomparedb" "false")
PLEXDB1=$(getConfig "--plex-db-1" "")
PLEXDB2=$(getConfig "--plex-db-2" "")
PLEXSTART1=$(getConfig "--plex-start-1" "")
PLEXSTOP1=$(getConfig "--plex-stop-1" "")
PLEXSTART2=$(getConfig "--plex-start-2" "")
PLEXSTOP2=$(getConfig "--plex-stop-2" "")
IGNORE=$(getConfig "--ignore-accounts" "")
PLEXF1="${TMPFOLDER}/1.sql"
PLEXF2="${TMPFOLDER}/2.sql"
TMPDB="${TMPFOLDER}/tmp.db"
IGNORESTR=$(getIgnore "$IGNORE")
checkRequired "--plex-db-1"
checkRequired "--plex-db-2"
checkRequired "--plex-start-1"
checkRequired "--plex-start-2"
checkRequired "--plex-stop-1"
checkRequired "--plex-stop-2"
printConfig
checkForDBs

stopServers
echoDN "Checking for changes... "
if checkForNew; then
	echo "Found"
	initFS
	initSql
	createTmpDB

	echoD "Processing tags..."
	processTags 1 "${PLEXF2}"
	processTags 2 "${PLEXF1}"

	# Get accounts on server 1
	sql "$PLEXDB1" "select id, name from accounts where lower(name) not in (${IGNORESTR}) order by id;"
	rowstr=$(declare -p rows)
	eval "declare -A accounts1="${rowstr#*=}
	num_accounts1=$num_rows

	# Get accounts on server 2
	sql "$PLEXDB2" "select id, name from accounts where lower(name) not in (${IGNORESTR}) order by id;"
	rowstr=$(declare -p rows)
	eval "declare -A accounts2="${rowstr#*=}
	num_accounts2=$num_rows

	for (( a1 = 0; a1 < num_accounts1; a1++ )); do
		for (( a2 = 0; a2 < num_accounts2; a2++ )); do
			# If a match, process
			if [ "${accounts1[$a1,"id"]}" == "${accounts2[$a2,"id"]}" ]; then
				echoD "Processing for ${accounts1[$a1,"name"]} (${accounts1[$a1,"id"]})..."

				# Start with records that are in both tables
				echoD "  - Checking records that are in both databases"
				processWatchedCommon ${accounts1[$a1,"id"]}

				# Then look at records that are on one server but not the other
				# We will start with server 1
				echoD "  - Checking records missing from server 2"
				processWatchedNew ${accounts1[$a1,"id"]} "${PLEXF2}" 1 2

				# And then server 2
				echoD "  - Checking records missing from server 1"
				processWatchedNew ${accounts1[$a1,"id"]} "${PLEXF1}" 2 1
			fi
		done
	done

	updateServers
	closeFS
else
	echo "None found"
fi
startServers
echoD "Finished."
