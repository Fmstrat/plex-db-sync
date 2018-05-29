# plex-db-sync
Synchronizes the database watched status between two Plex servers. This inlcudes watched times, and works for all users on the system without the need for tokens.

## Usage
To use the script, you will need to be able to access the databases of both Plex servers from one place. This can be done with programs like `sshfs`. For instance, you could run the script like this:
```
wget https://raw.githubusercontent.com/Fmstrat/plex-db-sync/master/plex-db-sync
apt-get install sshfs sqlite3
mkdir -p /mnt/sshfs
sshfs -o allow_other,IdentityFile=/keys/serverkey -p 22 \
	root@hostname.tld:"/var/lib/plexmediaserver/Library/Application Support/Plex Media Server/Plug-in Support/Databases/" \
	/mnt/sshfs
chmod +x plex-db-sync
./plex-db-sync \
	--plex-db-1 "/mnt/sshfs/com.plexapp.plugins.library.db" \
	--plex-start-1 "ssh -oStrictHostKeyChecking=no -i /keys/serverkey root@hostname.tld service plexmediaserver start" \
	--plex-stop-1 "ssh -oStrictHostKeyChecking=no -i /keys/serverkey root@hostname.tld service plexmediaserver stop" \
      	--plex-db-2 "/data/docker/containers/plex/config/Library/Application Support/Plex Media Server/Plug-in Support/Databases/com.plexapp.plugins.library.db" \
	--plex-start-2 "service plexmediaserver start" \
	--plex-stop-2 "service plexmediaserver stop" \
```
The script stops and starts Plex Media Server for a very short period of time to make updates. Due to buffering and reconnections, this does not impact clients when playing, except perhaps on the first run when a very large number of records are being updated.

## Docker
The following example is for docker-compose. It assumes you are running one Plex server locally, and another remotely.
```
version: '2'

services

  plex-db-sync:
    image: nowsci/plex-db-sync
    container_name: plex-db-sync
    volumes:
      - ./plex-db-sync/sshkey:/sshkey
      - /docker/plex/Library/Application Support/Plex Media Server/Plug-in Support/Databases/:/mnt/DB2
    cap_add:
      - SYS_ADMIN
    devices:
      - /dev/fuse
    security_opt:
      - apparmor:unconfined
    environment:
      - CRON=0 4 * * *
      - S1_SSH_KEY=/sshkey
      - S1_SSH_USER=root
      - S1_SSH_HOST=hostname
      - S1_SSH_PORT=22
      - S1_SSH_PATH="/docker/plex/Library/Application Support/Plex Media Server/Plug-in Support/Databases"
      - S1_START=ssh -oStrictHostKeyChecking=no -i /sshkey root@hostname 'cd /docker; docker-compose up -d plex'
      - S1_STOP=ssh -oStrictHostKeyChecking=no -i /sshkey root@hostname 'cd /docker; docker-compose stop plex'
      - S2_DB_PATH=/mnt/DB2
      - S2_START=cd /docker; docker-compose up -d plex
      - S2_STOP=cd /docker; docker-compose stop plex
    restart: always
```

## Options

Command Line | Docker Variable | Description 
------------ | --------------- | -----------
`--backup <true/false>` | `BACKUP` | Create a backup of the DB before running any SQL.
`--debug <true/false>` | `DEBUG` | Print debug output.
`--dry-run <true/false>` | `DRYRUN` | Don't apply changes to the DB.
`--plex-db-(1/2)` | `S(1/2)_DB_PATH` | Location of the server's DB. For the script, this is the file itself, for docker, it is the path.
`--plex-start-(1/2)` | `S(1/2)_START` | The command to start the Plex server.
`--plex-stop-(1/2)` | `S(1/2)_STOP` | The command to stop the Plex server.
n/a | `CRON` | A string that defines when the script should run in crond (Default is 4AM)
n/a | `S(1/2)_SSH_KEY` | The SSH identity file.
n/a | `S(1/2)_SSH_USER` | The SSH user.
n/a | `S(1/2)_SSH_HOST` | The SSH host.
n/a | `S(1/2)_SSH_PORT` | The SSH port.
n/a | `S(1/2)_SSH_PATH` | Path to the database file on the SSH server.
