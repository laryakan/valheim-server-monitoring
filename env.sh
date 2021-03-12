#!/bin/bash
# author: laryakan, date 2021/03/12
# VMS env file, everything between "set -o allexport" and "set +o allexport" will be exported
set -o allexport
# Root dir
VSMDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# Valheim server dir
VHSERVERDIR=''
# Logs dir
VALHEIMSERVERLOGSDIR="$VSMDIR/valheim-logs.d"

### STATUS ###
# Valheim server PID; If you run more than one server, please add a PID file
#VALSERVERPID=`cat valheim-server.pid`
VALSERVERPID=`pgrep valheim_server`
# Connected players list
CONNECTEDPLAYERSFILE="$VSMDIR/data/online-players"
# Offline players list
OFFLINEPLAYERSFILE="$VSMDIR/data/offline-players"

### STATUS OVER HTTP ###
# Port listening for ncat valheim server status over HTTP in nreal time
STATUSPORT=8181

### DISCORD WEBHOOK ###
# Create your webhook on the desired channel in Discord, then paste your webhook id and token here
WEBHOOKID='<your-webhook-id>'
WEBHOOKTOKEN='<your-webhook-token>'
# At first launch, the webhook will create a new message. If you want the webhook to update your message
# instead of creating new ones, paste the message id here. CAUTION: The webhook and only update its own messages
STATUSMESSAGEID=''
# If you want the webhook to send logs, 0 if you dont want you webhook to send logs
SENDLASTLOGS=0
# Logs messages id in your discord channel once posted (if SENDLASTLOGS!=0 )
LASTLOGMESSAGEID=''


set +o allexport
#EOF
