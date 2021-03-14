#!/bin/bash
# author: laryakan, date 2021/03/12
# Basic env init
CWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
if [ ! -f "$CWD/.env" ]
then
  cp "$CWD/.env.dist" "$CWD/.env"
fi
source "$CWD/.env"

# VSM Setup menu
# Colors
red='\e[31m'
green='\e[32m'
blue='\e[94m'
cyan='\e[36m'
yellow='\e[93m'
magenta='\e[35m'
clear='\e[0m'
ColorRed(){
	echo -ne $red$1$clear
}
ColorGreen(){
	echo -ne $green$1$clear
}
ColorBlue(){
	echo -ne $blue$1$clear
}
ColorCyan(){
	echo -ne $cyan$1$clear
}
ColorYellow(){
	echo -ne $yellow$1$clear
}
ColorMagenta(){
	echo -ne $magenta$1$clear
}

# get the setup status
# Setup service with conf values
function setup_status(){
	echo -ne "
---------------------------------------
========== VSM- Setup status ==========
"
if [ ! -z $VALSERVERPID ];then echo -e "Valheim Server $(ColorGreen online)";else echo -e "Valheim Server $(ColorRed offline)";fi
if [ ! -z $(pgrep $(basename $VSMLOGFILTER)) ];then echo -e "VSM logs filter $(ColorGreen running)";else echo -e "VSM logs filter $(ColorRed stopped) or $(ColorRed 'not piped!')";fi
if [ "$VHSERVERWORLD" != 'server.world' ];then echo -e "Custom launcher world $(ColorGreen 'is set')";else echo -e "Custom launcher world $(ColorRed 'has default value')";fi
if [ -e '/etc/logrotate.d/valheim' ];then echo -e "logrotate $(ColorGreen set)";else echo -e "logrotate $(ColorRed 'not set')";fi
if [ "$WEBHOOKTOKEN" != 'webhookToken' ];then echo -e "$(ColorMagenta 'Discord') webhook $(ColorGreen ready)";else echo -e "$(ColorMagenta 'Discord') webhook $(ColorRed 'not ready')";fi
if [ ! -z "$STATUSMESSAGEID" ];then echo -e "$(ColorMagenta 'Discord') webhook $(ColorGreen 'can update status')";else echo -e "$(ColorMagenta 'Discord') webhook $(ColorRed 'cannot update status')";fi
if [ ! -z $(crontab -l 2>/dev/null | grep "$WEBHOOKUPDATE") ];then echo -e "Webhook crontab $(ColorGreen 'is set')";else echo -e "Webhook crontab $(ColorRed 'not set')";fi
if [ -e "/etc/systemd/system/$VHSERVERSERVICENAME" ];then echo -e "$VHSERVERSERVICENAME is $(ColorGreen 'present') in system";else echo -e  "$VHSERVERSERVICENAME is $(ColorRed 'missing') in system";fi
if [ -e "/etc/systemd/system/$VSMHTTPSERVICENAME" ];then echo -e "$VSMHTTPSERVICENAME is $(ColorGreen 'present') in system";else echo -e  "$VSMHTTPSERVICENAME is $(ColorRed 'missing') in system";fi

echo ""
echo "--Ports--"
echo -e "Please, run \e[1msudo ufw status\e[0m (firewall) to see if these ports are open:"
echo -e "- $VHSERVERPORT to $(($VHSERVERPORT+2))/tcp/udp (Valheim server)"
echo -e "- $STATUSPORT/tcp (VSM over HTTP)"
}

# env conf value changing function
function replace_env_value() {
  cat "$CWD/.env"|grep "$1="|xargs -I {} -t sed -i "s[{}[$1=\"$2\"[ig" "$CWD/.env"
  source "$CWD/.env"
}

# param1=value_label, param2=value_variable_in_.env
function setup_value_prompt() {
  echo ""
	echo "**$1**"
	echo -e "current value : ${!2}"
	echo "enter new value ('n' to leave unchanged) :"
	read NEWVALUE
	if [ "$NEWVALUE" = 'n' ];then
	  echo "value unchanged"
	  return
	fi
	replace_env_value "$2" "$NEWVALUE"
	echo "new value set : ${!2}"
	echo ""
}

# trying autoconfig
function auto_conf(){
	# Searching for Valheim server dir
	# Searching for running Valheim server to complete
	VHSERVERPROCESS=$(ps -auxwe|grep -v grep|grep valheim_server)
	# if process found
	if [ ! -z "$VHSERVERPROCESS" ]
	then
		# get the user who will execute services
		FUSERSERVICE=$(echo $VHSERVERPROCESS|cut -d' ' -f1)
		replace_env_value 'USERSERVICE' "$FUSERSERVICE"
		# get path
		FVHSERVERDIR=$(echo $VHSERVERPROCESS|sed -n -e 's/^.*PWD=//p'|cut -d' ' -f1)
		replace_env_value 'VHSERVERDIR' "$FVHSERVERDIR"
		# get Valheim server port
		FVHSERVERPORT=$(echo $VHSERVERPROCESS|sed -n -e 's/^.*-port //p'|cut -d' ' -f1)
		replace_env_value 'VHSERVERPORT' $FVHSERVERPORT
		# get Your server name
		FVHSERVERNAME=$(echo $VHSERVERPROCESS|sed -n -e 's/^.*-name //p'|cut -d' ' -f1)
		replace_env_value 'VHSERVERNAME' "$FVHSERVERNAME"
		# get you server world name
		FVHSERVERWORLD=$(echo $VHSERVERPROCESS|sed -n -e 's/^.*-world //p'|cut -d' ' -f1)
		replace_env_value 'VHSERVERWORLD' "$FVHSERVERWORLD"
		# get Your server password
		FVHSERVERPASSWD=$(echo $VHSERVERPROCESS|sed -n -e 's/^.*-password //p'|cut -d' ' -f1)
		replace_env_value 'VHSERVERPASSWD' "$FVHSERVERPASSWD"
	fi
}

# Setup cron
function set_cron() {
	# Check a and old cron exists
	$OLDLINE="$( crontab -l | grep "$WEBHOOKUPDATE" )"
	if [ ! -z "$OLDLINE" ]
	then
		if [ $CRONTABWEBHOOKFREQ -eq 0 ]
		then
			# remove line
			crontab -l 2>/dev/null | grep -v "$OLDLINE" | crontab -
		else 
			# remove line, add new one
			(crontab -l 2>/dev/null | grep -v "$OLDLINE" ; echo "*/$CRONTABWEBHOOKFREQ * * * * $WEBHOOKUPDATE") | crontab -
		fi
	else
		if [ $CRONTABWEBHOOKFREQ -gt 0 ]
		then
			# add new one
			(crontab -l 2>/dev/null ; echo "*/$CRONTABWEBHOOKFREQ * * * * $WEBHOOKUPDATE") | crontab -
		fi
	fi
	echo "crontab updated, you can check it with *crontab -l*, edit with *crontab -e*"
}

# Setup service with conf values
function set_service(){
	SERVICENAME="$1"
	cp "$CWD/examples/$SERVICENAME" "$CWD/systemd/$SERVICENAME"

	# steam real exec user
	sed -i "s[###EXECUSER###[$USERSERVICE[g" "$CWD/systemd/$SERVICENAME"

	if [ "$SERVICENAME" = "$VHSERVERSERVICENAME" ]
	then
	# set steamcmd path for server update
	sed -i "s[###STEAMCMDPATH###[$STEAMCMD[g" "$CWD/systemd/$SERVICENAME"
	# set valheim server dir for server update
	sed -i "s[###STEAMCMDPATH###[$STEAMCMD[g" "$CWD/systemd/$SERVICENAME"
	# important : set launcher path
	sed -i "s[###VHSERVERLAUNCHER###[$VHSERVERLAUNCHER[g" "$CWD/systemd/$SERVICENAME"
	# important : set launcher dir
	sed -i "s[###VHSERVERLAUNCHERDIR###[$VHSERVERLAUNCHERDIR[g" "$CWD/systemd/$SERVICENAME"
	fi

	if [ "$SERVICENAME" = "$VSMHTTPSERVICENAME" ]
	then
	# set steamcmd path for server update
	sed -i "s[###VSMHTTP###[$VSMHTTP[g" "$CWD/systemd/$SERVICENAME"
	# set valheim server dir for server update
	sed -i "s[###VSMHTTPDIR###[$VSMHTTPDIR[g" "$CWD/systemd/$SERVICENAME"
	fi
	# binding with systemd
	sudo ln -s "$CWD/systemd/$SERVICENAME" "/etc/systemd/system/$SERVICENAME"
	NOSUDO=$?
	# missing sudo fallback
	if [ $NOSUDO -gt 0 ]
	then 
		echo -e "$(ColorRed 'Since sudo has failed, here s the command we tried : ')"
		echo -e "sudo ln -s \"$CWD/systemd/$SERVICENAME\" \"/etc/systemd/system/$SERVICENAME\""
		echo -e "sudo systemctl daemon-reload"
		echo -e "sudo systemctl start $SERVICENAME"
	else 
		sudo systemctl daemon-reload
		sudo systemctl start $SERVICENAME
		echo -e "$(ColorGreen 'service set and started')"
	fi
	echo -e "if the service is set, you can auto-start after reboot using \"systemctl enable $SERVICENAME\""
}

function uninstall_service(){
	SERVICENAME="$1"
	sudo systemctl stop "$SERVICENAME"
	sudo systemctl disable "$SERVICENAME"
	sudo rm "/etc/systemd/system/$SERVICENAME"
	sudo systemctl daemon-reload
	sudo systemctl reset-failed
}

# Setup service with conf values, setup is $1=1; setdown is $1=2
function set_logrotate(){
	cp "$CWD/examples/valheim.logrotate" "$CWD/systemd/valheim.logrotate"

	# set real path
	sed -i "s[###VALHEIMSERVERLOGSDIR###[${VALHEIMSERVERLOGSDIR}[g" "$CWD/systemd/valheim.logrotate"
	sudo ln -s "$CWD/systemd/valheim.logrotate" "/etc/logrotate.d/valheim"
	NOSUDO=$?
	# missing sudo fallback
	if [ $NOSUDO -gt 0 ]
	then 
		echo -e "$(ColorRed 'Since sudo has failed, here s the command we tried : ')";
		echo -e "sudo ln -s \"$CWD/systemd/valheim.logrotate\" \"/etc/logrotate.d/valheim\"";
	else 
		echo -e "$(ColorGreen 'logrotate set')"
	fi
}

service_menu(){
echo -ne "
---------------------------------------
=== Valheim Server Monitoring - VSM ===
*** Service menu ***
$(ColorGreen '1) get the setup status')
$(ColorGreen '2)') setup a user for executing services
$(ColorGreen '3)') setup Valheim server launcher (recommended to user default custom launcher)

=> Advanced options <=
$(ColorGreen '4)') setup $(ColorMagenta 'Discord') webhook update cron frequency
$(ColorGreen '5)') $(ColorYellow 'sudo recommended'), activate logrotate on Valheim server logs
$(ColorGreen '6)') $(ColorYellow 'sudo recommended'), add and activate valheim-server.service (your server through service) $(ColorRed 'stop you server first !')
$(ColorGreen '7)') $(ColorYellow 'sudo recommended'), add and activate vsm.http.service (server status over HTTP)

$(ColorGreen '0)') return to previous menu
$(ColorGreen 'CTRL+C)') quit
$(ColorBlue 'You can scroll up to see previous screens')
$(ColorBlue 'choose an option:') "
mkdir -p "$CWD/systemd"
        read a
        case $a in
			1) clear ; setup_status ; service_menu ;;
	        2) setup_value_prompt 'whats the user you want to execute service ?' 'VALHEIMSERVERLOGSDIR' ; clear ; service_menu ;;
			3) setup_value_prompt "which launcher do you want to use ? remember to put server output on $( basename $VSMLOGFILTER ) stdin" 'VHSERVERLAUNCHER' ; clear ; service_menu ;;
			4) setup_value_prompt "at which frequency do you want your $(ColorMagenta 'Discord') webhook to send message (in minutes) ? set '0' if you dont want an auto-update cron" 'CRONTABWEBHOOKFREQ' ; set_cron ; sleep 2 ; clear ; service_menu ;;
			5) set_logrotate ; sleep 5 ; clear ;  service_menu ;;
			6) set_service "$VHSERVERSERVICENAME"; sleep 10 ; clear ;  service_menu ;;
			7) set_service "$VSMHTTPSERVICENAME"; sleep 10 ; clear ;  service_menu ;;

		0) clear ; menu ;;
		*) echo -e $red"Wrong option."$clear; WrongCommand;;
        esac
}

uninstall_menu(){
echo -ne "
---------------------------------------
=== Valheim Server Monitoring - VSM ===
*** Uninstall menu ***
$(ColorGreen '1) get the setup status')
$(ColorGreen '2)') remove webhook crontab (no more auto-update)
$(ColorGreen '3)') $(ColorRed 'sudo required') remove logrotate on server logs
$(ColorGreen '4)') $(ColorRed 'sudo required') remove valheim-server.service (your server through service)
$(ColorGreen '5)') $(ColorRed 'sudo required') remove vsm.http.service (server status over HTTP)

=> Uninstall all <==
$(ColorGreen '10)') $(ColorRed 'sudo required') remove all previously listed components

$(ColorGreen '0)') return to previous menu
$(ColorGreen 'CTRL+C)') quit
$(ColorBlue 'You can scroll up to see previous screens')
$(ColorBlue 'choose an option:') "
mkdir -p "$CWD/systemd"
        read a
        case $a in
	        1) clear ; setup_status ; uninstall_menu ;;
			2) replace_env_value 'CRONTABWEBHOOKFREQ' 0 ; set_cron ; sleep 2 ; clear ; uninstall_menu ;;
			3) sudo rm '/etc/logrotate.d/valheim' ; clear ; uninstall_menu ;;
			4) uninstall_service "$VHSERVERSERVICENAME" ; clear ; uninstall_menu ;;
			5) uninstall_service "$VSMHTTPSERVICENAME" ; clear ; uninstall_menu ;;
			10) replace_env_value 'CRONTABWEBHOOKFREQ' 0 ; set_cron ; sudo rm '/etc/logrotate.d/valheim' ; uninstall_service "$VHSERVERSERVICENAME" ; uninstall_service "$VSMHTTPSERVICENAME" ; clear ; uninstall_menu ;;


		0) clear ; menu ;;
		*) echo -e $red"Wrong option."$clear; WrongCommand;;
        esac
}

menu(){
echo -ne "
---------------------------------------
=== Valheim Server Monitoring - VSM ===
$(ColorBlue 'If its a new install, follow steps in order.')
$(ColorBlue 'If you have setted things manually for version <2, please reset your server state')
$(ColorRed 'Please, pipe your valheim server start script (launcher) on')
$(ColorRed $VSMLOGFILTER)
$(ColorRed 'or use my launcher, steps 10),11),12),13) and 14) + service setup -> 20) then 6) in service menu')
$(ColorGreen '1) get the setup status')
$(ColorGreen '2)') setup wanted Valheim server logs directory
$(ColorGreen '3)') setup wanted Valheim server status over HTTP URL (host:port)
$(ColorBlue 'You can find the script to launch VSM HTTP in status directory, or create a service in service menu')

=> Setting up $(ColorMagenta 'Discord') webhook <==
$(ColorRed 'Remember to first create your webhook on Discord and activate developer mode (appereance menu)')
$(ColorGreen '4)') setup current $(ColorMagenta 'Discord') webhook URL
$(ColorGreen '5)') setup 'how many' wanted last logs on your $(ColorMagenta 'Discord') channel
$(ColorGreen '6)') force $(ColorMagenta 'Discord') webhook update
$(ColorGreen '7)') setup current $(ColorMagenta 'Discord') webhook status message id
$(ColorGreen '8)') setup current $(ColorMagenta 'Discord') webhook last logs message id

=> Setting up custom launcher <==
$(ColorGreen '10)') setup current Valheim server directory
$(ColorGreen '11)') setup wanted Valheim server listening port
$(ColorGreen '12)') setup wanted Valheim server name
$(ColorGreen '13)') setup wanted Valheim server world name
$(ColorGreen '14)') setup wanted Valheim server password
$(ColorGreen '15)') $(ColorRed bugged) if your server is running, you can try auto conf
$(ColorBlue 'You can find the launcher inside "launcher" directory, or create a service')

=> Advanced options <==
$(ColorGreen '20)') $(ColorYellow 'sudo recommended'), service menu
$(ColorGreen '30)') $(ColorYellow 'sudo recommended'), uninstall menu

$(ColorGreen '0)') quit
$(ColorGreen 'CTRL+C)') quit
$(ColorBlue 'You can scroll up to see previous screens')
$(ColorBlue 'choose an option:') "
        read a
        case $a in
			1) clear ; setup_status ; menu ;;
	        2) setup_value_prompt 'where do you want to put logs ?' 'VALHEIMSERVERLOGSDIR' ; clear ; menu ;;
	        3) setup_value_prompt 'set the public URL of your VSM over HTTP status (http://host:port) ?' 'STATUSURL' ; clear ; menu ;;
			4) setup_value_prompt "what's your $(ColorMagenta 'Discord') webhook url ?" 'WEBHOOKURL' ; clear ; menu ;;
	        5) setup_value_prompt "how many logs do you want on your $(ColorMagenta 'Discord') ? set '0' if you dont want any" 'SENDLASTLOGS' ; clear ; menu ;;
	        6) "$CWD/discord/update" ; clear ; menu ;;
	        7) setup_value_prompt "what's the $(ColorMagenta 'Discord') webhook status message id ?" 'STATUSMESSAGEID' ; clear ; menu ;;
	        8) setup_value_prompt "what's the $(ColorMagenta 'Discord') webhook 'last logs' message id ?" 'LASTLOGMESSAGEID' ; clear ; menu ;;
	        10) setup_value_prompt 'where is located your dedicated server ?' 'VHSERVERDIR' ; clear ; menu ;;
	        11) setup_value_prompt 'on which port do you want your server to listen (default: 2456) ?' 'VHSERVERPORT' ; clear ; menu ;;
	        12) setup_value_prompt 'what is your $(ColorYellow 'current') or $(ColorCyan 'wanted')  Valheim server name ?' 'VHSERVERNAME' ; clear ; menu ;;
	        13) setup_value_prompt "what is your Valheim World name ? $(ColorRed 'If you already have a server, put its World name here')" 'VHSERVERWORLD' ; clear ; menu ;;
	        14) setup_value_prompt 'what is your $(ColorYellow 'current') or $(ColorCyan 'wanted')  Valheim server password ?' 'VHSERVERPASSWD' ; clear ; menu ;;
			15) auto_conf ; clear ; menu ;;
	        20) clear ; service_menu ;;
			30) clear ; uninstall_menu ;;
		0) exit 0 ;;
		*) echo -e $red"Wrong option."$clear; WrongCommand;;
        esac
}

# Call the menu function
clear ; menu
