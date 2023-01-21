#!/bin/bash

clear

# Keep track of the initial directory.
initial_dir="$PWD"

# SIMPLEHELP INSTALLATION DIR
install_dir="/opt/SimpleHelp"
if [ ! -z "$1" ]; then
    install="$1"
fi

# BACKUP DIR (tar archives).
backup_dir=/mnt/samba/backups
# LAST CONFIGURATION DIR 
last_config_dir=/mnt/samba/backups/last-configuration

# Check permissions
parentdir="$(dirname "$install_dir")"
if [ ! -w "$parentdir" ]; then
    echo "[ERROR] Insufficient permissions to write installation files in $parentdir" >&2
    exit 1
fi
if [ -d "$install_dir" ]; then
    if [ ! -w "$parentdir" ]; then
        echo "[ERROR] Insufficient permissions to write installation files in $install" >&2
        exit 1
    fi
fi

# add a bit of colour to the menus
colBlue="\e[34m"
colGreen="\e[32m"
colRed="\e[31m"
colEnd="\e[0m"

SH_Ver=0

function SH_Backup () {
# * SimpleHelp Backup Function                   *
# ************************************************

	clear
	
	local sh_build=$(SH_AllVersions)
	local sh_archive="simplehelp_backup_"$(date +"%Y%m%d_%H%M%S")
	local sh_config="$install_dir/configuration/"
	local tar_command="$backup_dir/$sh_archive.tar  configuration"
	
	echo "*-------------------------------------**-------------------------------------*"
	echo "*  Backup SimpleHelp Configuration..."
	echo "*----------------------------------------------------------------------------*"
	#echo "*"
	echo -e "*  Backup Archive:		[${colGreen}$sh_archive.tar${colEnd}]"
	echo -e "*  Configuration Directory :	[${colGreen}$sh_config${colEnd}]"
	echo -e "*  Backup Directory:		[${colGreen}$backup_dir${colEnd}]"
	#echo "*"
	echo "*----------------------------------------------------------------------------*"
    echo 
	echo "Please wait.."
	
	SH_ServiceStop
	#cd $install_dir
	
	# CONFIG BACKUP
	# save configuration to tar 
	# **************************
	echo "Creating archive: $sh_archive.tar" 
	tar -cf $tar_command
	# save the current sh ver with backup
	echo "Creating version file: $sh_archive.txt" 
	echo "$sh_build" >> "$backup_dir/$sh_archive.txt"
	
	SH_ServiceStart
	echo 
	read -p 'Press any key to continue... ' nullChoice
	
	return 1
}

function SH_Restore () {
# * SimpleHelp Install and Upgrade Function      *
# ************************************************

local validChoice=0
local sh_build=$(SH_AllVersions)

until [  "$validChoice" = "1" ]
do
	clear
	
	sh_archive="Full_Simplehelp_Backup_"$(date +"%Y%m%d_%H%M%S")
	tar_command="$last_config_dir/$sh_archive.tar SimpleHelp"  #configuration
	
	n=1
	
	echo "*----------------------------------------------------------------------------*"
	echo "*  Restore SimpleHelp Configuration..."
	echo "*----------------------------------------------------------------------------*"
	echo
	echo "  Available Backups:"
	echo " -----------------------------------------------------------------------------"
	
	for entry in "$backup_dir"/*.tar
	do
		echo "  $n: $entry"
		#echo $n":" "$entry"
		#backups[$n]=$entry
		files[$n]="$entry"
		#arrayIndex=$n
		((n=n+1))
	done

	echo
	
	read -p 'Select a backup to restore: ' mnuChoice

	fchoice=${files[$mnuChoice]}

	#echo $fchoice

	if [[ -n "$fchoice" ]];then
                #Exit loop if valid selection
		validChoice=1
	fi
	
done

	echo
	echo "*----------------------------------------------------------------------------*"
	echo -e "*  Archive: [${colGreen}${files[$mnuChoice]}${colEnd}]"
	echo -e "*  Installation Dir: [${colGreen}$install_dir/configuration${colEnd}]"
	echo -e "*  Configuration Backup Dir:  [${colGreen}$last_config_dir${colEnd}]"
	echo "*----------------------------------------------------------------------------*"
	echo
	read -p 'Continue (Y)es or (n)o? Default : Yes ' mnuChoice
	
	if [  "$mnuChoice" = "Y" ] || [  "$mnuChoice" = "y" ]; then
		#echo "Stopping..."
		#exit 0
	#else
		SH_ServiceStop

		# backup current config to archive
		# Save this to tar with $now
		echo "Saving backup to: $sh_archive"
		cd $install_dir
		cd ..
		
		# FULL BACKUP
		# save install to tar 
		# **************************
		tar -cf $tar_command
		# save the current sh ver with backup
		echo "$sh_build" >> "$last_config_dir/$sh_archive.txt"
		
		#  move current config
		echo "Moving current config..."
		#mv -R "$install_dir"/configuration/  "$install_dir"/

		# restore config from tar
		echo "Restoring configuration from archive..."
		#unzip -o ${files[$FileChoice]} -d $install_dir
		
		SH_ServiceStart
		
		echo
		read -p 'Press any key to continue... ' nullChoice
	fi

return 1
}

function SH_Install_Upgrade () {
# * SimpleHelp Install and Upgrade Function      *
# ************************************************

	clear
	
	echo "*-------------------------------------**-------------------------------------*"
	echo "*  Install/Upgrade SimpleHelp..."
	echo "*----------------------------------------------------------------------------*"
	echo "*"
	echo -e "*  Installation Directory :	[${colGreen}$install_dir${colEnd}]"
	echo "*"
	echo "*----------------------------------------------------------------------------*"
    echo 
	
	# Generate a timestamp
	local now=$(date +"%Y%m%d_%H%M%S")

	# Stop the server
	if [ -d "$install_dir" ]; then
		SH_ServiceStop
		cd "$install_dir"
		cd ..
		echo "Backing up the SimpleHelp installation to SimpleHelp_backup_$now..."
		#mv "$install_dir" "SimpleHelp_backup_$now"
	fi

	# Fetch the new version
	uname_out=`uname -m`
	case "$uname_out" in
		*aarch64*|*arm64*)
			echo "Using the Linux ARM 64bit Release..."
			sh_binary="SimpleHelp-linux-arm64.tar.gz"
			sh_url="https://simple-help.com/releases/SimpleHelp-linux-arm64.tar.gz"
		;;
		*aarch*|*arm*)
			echo "Using the Linux ARM 32bit Release..."
			sh_binary="SimpleHelp-linux-arm32.tar.gz"
			sh_url="https://simple-help.com/releases/SimpleHelp-linux-arm32.tar.gz"
		;;
		*64*)
			echo "Using the Linux Intel 64bit Release..."
			sh_binary="SimpleHelp-linux-amd64.tar.gz"
			sh_url="https://simple-help.com/releases/SimpleHelp-linux-amd64.tar.gz"
		;;
		*)
			echo "Using the Linux Intel 32bit Release..."
			sh_binary="SimpleHelp-linux.tar.gz"
			sh_url="https://simple-help.com/releases/SimpleHelp-linux.tar.gz"
		;;
	esac

	#rm -f $sh_binary
	echo "Downloading the latest version..."
	# Download quiet but show progress only
	wget -q $sh_url --show-progress
	echo "Extracting..."
	#tar -xzf $sh_binary

	if [ "$install_dir" != "$PWD/SimpleHelp" ]; then
		echo "Moving install to $install_dir..."
		#mv SimpleHelp "$install_dir"
	fi

	# Copy across the old configuration folder
	if [ -d "SimpleHelp_backup_$now" ]; then
		echo "Copying across configuration files..."
		#cp -R $install_dir/../SimpleHelp_backup_$now/configuration/* $install_dir/configuration
	fi

	# Start the new server
	SH_ServiceStart
	
	echo
	read -p 'Press any key to continue... ' nullChoice
	
	return 5 
}

function SH_Utils () {

result="`wget -qO- http://127.0.0.1/allversions`"
#result=($(result//\n/ })
echo  $result 
#echo $("$result" | grep "SH Version" | awk '{print $3}' | sed s/"SSuite-"//)
read -p 'Press any key to continue... ' nullChoice

return 1
}

function SH_LatestVersion () {
# * SimpleHelp Latest Version Function           *
# ************************************************

FILE="$install_dir/configuration/latestversion"

if [ -f "$FILE" ]; then
    echo $(<"$install_dir/configuration/latestversion")
	return 1
fi
}

function SH_AllVersions () {
result="`wget -qO- http://127.0.0.1/allversions`"
echo "$result"
}

function SH_CurentVersion () {
# * SimpleHelp  Current Version Function                        *
# * Try and get the current sh version from the running server. *
# ***************************************************************

wget  -q http://127.0.0.1/allversions -O /tmp/sh_info
result=$(cat /tmp/sh_info | grep "SH Version" | awk '{print $3}' | sed s/"SSuite-"//)

#shver=$(cat /tmp/sh_info | grep "Visual Version" | awk '{print $3}' | sed s/"SSuite-"//)
#SH_Ver=$shver
#echo $SH_Ver

rm /tmp/sh_info

if [ "$result" = "" ]; then
	echo "0"
	return 1
else
	echo "$result"
	return 0
fi

}

function SH_ServiceStatus () {
# * SimpleHelp Service Status Function           *
# ************************************************
	#echo "checking service status.."
	if [ -z "`ps axf | grep ProxyServerStartup | grep -v grep`" ]; then
		# SH not running
		echo "no"
		return 0
    else
		# SH running
		echo "yes"
		return 1
	fi
	
	# return value 0 and 1 are returned in $?
}

function SH_ServiceStart () {
# * SimpleHelp Service Start Function            *
# ************************************************
	
	if [ "$(SH_ServiceStatus)" = "yes" ]; then 
		#SH Already running
		echo "Already Running.."
		return 0
	elif [ "$(SH_ServiceStatus)" = "no" ]; then
		#Start SH
		echo "Starting Service..."
		cd "$install_dir"
		sh serverstart.sh >/dev/null 2>&1
		sleep 5
		return 1
	#else
	#	#Failed to start
	#	echo "Failed to start.."
	#	return 0
	fi
}

function SH_ServiceStop () {
# * SimpleHelp Service Stop Function             *
# ************************************************
	if [ "$(SH_ServiceStatus)" = "yes" ]; then 
		#SH running, stop service
		echo "Stopping Service.."
		cd "$install_dir"
		sh serverstop.sh >/dev/null 2>&1
		sleep 15
		return 1
	elif [ "$(SH_ServiceStatus)" = "no" ]; then
		#Start SH
		echo "Service not running..."
		return 0
	#else
	#	#Failed to stop
	#	echo "Failed to stop.."
	#	return 0
	fi
}

function SH_SystemD () {
# * SimpleHelp SystemD Function                  *
# ************************************************

outFile="/mnt/samba/simplehelp.service"

echo "[Unit]" >> $outFile
echo "Description=SimpleHelp Server" >> $outFile
echo "After=network.target" >> $outFile
echo " " >> $outFile
echo "[Service]" >> $outFile
echo "WorkingDirectory=$install_dir/" >> $outFile
echo "Type=forking" >> $outFile
echo "ExecStart=/bin/bash $install_dir/serverstart.sh" >> $outFile
echo "ExecStop=/bin/bash $install_dir/serverstop.sh" >> $outFile
echo " " >> $outFile
echo "[Install]" >> $outFile
echo "WantedBy=multi-user.target" >> $outFile

chmod 644 $outFile

return 1
}

function ColorRed () {
	echo -ne $colRed$1$colEnd
}

function ColorGreen(){
	echo -ne $colGreen$1$colEnd
}

function ColorBlue(){
	echo -ne $colBlue$1$colEnd
}

function SH_Prequisites () {
# SimpleHelp Prequisites Check Function *
#                                       *
# Very experimental this function       *
# check if sh running before showing    *
# menu, then check for server response  *
# 
#****************************************         

sh_response=0
retries=0

if [ "$(SH_ServiceStatus)" = "no" ]; then
	# Just exit
	echo "SH Running: [$(ColorGreen "no")]"
	sleep 1
	return 1
else
	echo "SH Running: [$(ColorGreen "yes")]"
	# stay in the loop until response from server or retries = 5
	# NOTE: if two expressions then use [[ a = b || c = c ]]
	until [ $retries = "5" ]
	do
		if [ $(SH_CurentVersion) != "0" ]; then
			# got a reponse
			echo "Build: [$(ColorGreen "$(SH_CurentVersion)")]"
			echo "Version: [$(ColorGreen "$SH_Ver")]"
			
			# Experimental, check if update available and set global flag
			if [  $(SH_LatestVersion) != $(SH_CurentVersion) ];  then
				SH_UpdateAvailable="1"
				echo "Update Available: [$(ColorGreen "$(SH_LatestVersion)")]"
			fi
			
			sleep 2
			return 0
		fi
		
		# just make sure we only stay in this loop so long
		((retries=retries+1))
		#Just sleep 2 sec
		sleep 2
		
	done
	
	echo "nooooo"
	# shouldnt really get to here.
	return 0
fi
}

# ************************************************
# * SimpleHelp Server helper script v1 MAIN MENU *
# ************************************************

SH_UpdateAvailable="0"

# do prequisites here first before displaying menus
# 1) check if sh running, if not show menu
# 2) if running try and get a response from server.
# 3) if response update global variables, then show menu.

SH_Prequisites

#echo "$?"
#exit 1

# In a loop from here until x
until [  "$mnuChoice" = "X" ] || [  "$mnuChoice" = "x" ]
do
	clear
	
	#echo -e $(ColorBlue "Testing testing.....")
	echo "*----------------------------------------------------------------------------*"
	echo -e "*  SimpleHelp Server Tools v1"
	echo "*----------------------------------------------------------------------------*"
	echo -e "*  Install Dir: [${colGreen}$install_dir${colEnd}]	SH Build: [${colGreen}$(SH_CurentVersion)${colEnd}]"
	echo -e "*  Backup Dir : [${colGreen}$backup_dir${colEnd}]	SimpleHelp Running: [${colGreen}$(SH_ServiceStatus)${colEnd}]"
	echo "*----------------------------------------------------------------------------*"
	echo ""
	echo "  1: Backup SimpleHelp Configuration."
	echo "  2: Restore SimpleHelp Configuration."
	
	# Show if update available, bit experimental
	if [ $SH_UpdateAvailable = "1" ];  then
		echo -e "  3: Install/Upgrade SimpleHelp. $colGreen[Update Available]$colEnd"
	elif [ $SH_UpdateAvailable = "0" ];  then
		echo "  3: Install/Upgrade SimpleHelp."
	fi
	
	echo "  4: Utilities"
	echo "  x: Exit."
	echo ""
	#echo ""

	read -p 'Choose an option: ' mnuChoice

		if [  "$mnuChoice" = "1" ]; then 
			echo "SimpleHelp Backup..."
			SH_Backup
		elif [  "$mnuChoice" = "2" ]; then
			echo "SimpleHelp Restore..."
			SH_Restore
		elif [  "$mnuChoice" = "3" ]; then
			echo "SimpleHelp Install/Upgrade..."
			SH_Install_Upgrade
		elif [  "$mnuChoice" = "4" ]; then
			echo "Utilities..."
			SH_Utils
		fi
done

cd $initial_dir