#!/bin/bash

clear

# Keep track of the initial directory.
initial_dir="$PWD"

# sh-tools.sh pid file
sh_pid="/var/run/sh-tools.pid"

# SIMPLEHELP INSTALLATION DIR
install_dir="/opt/SimpleHelp"
if [ ! -z "$1" ]; then
    install="$1"
fi

# Check permissions of install_dir
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

# BACKUP DIR [tar archives].
backup_dir="/mnt/samba/backups"
# FULL BACKUP DIR [tar archives].
full_backup_dir="$backup_dir/full"

# add a bit of colour to the menus
colBlue="\e[34m"
colGreen="\e[32m"
colRed="\e[31m"
colEnd="\e[0m"

SH_Ver=0
SH_Build=0

# SimpleHelp Prequisites Check Function *
#                                       *
# Very experimental this function       *
# check if sh running before showing    *
# menu, then check for server response  *
# ** also check if backup paths exist **
#****************************************   
function SH_Prequisites () {

sh_response=0
retries=0

# check if were already running another instance
for pid in $(pidof -x sh-tools.sh); do
		if [ $pid != $$ ]; then
			# warn and exit
			echo "*-----------------------------------------------------------------"
			echo "*  Warning: [$(ColorRed "sh-tools.sh is already running with PID $pid")]"
			echo "*  Do you want to terminate this process..."
			echo "*-----------------------------------------------------------------"
			echo 

			until [  "$mnuChoice" = "Y" ] || [  "$mnuChoice" = "y" ] || [  "$mnuChoice" = "N" ] || [  "$mnuChoice" = "n" ]
			do
				read -p '(Y)es (N)o: ' mnuChoice

				if [  "$mnuChoice" = "Y" ] || [  "$mnuChoice" = "y" ]; then
					kill $pid
					trap "rm -f $sh_pid" EXIT
				fi
			done

			exit 1
    	fi
done

if [ "$(SH_ServiceStatus)" = "no" ]; then
	# Just exit
	echo "SH Running: [$(ColorGreen "no")]"
	sleep 1
	return 0
else
	echo "SH Running: [$(ColorGreen "yes")]"
	# stay in the loop until response from server or retries = 5
	# NOTE: if two expressions then use [[ a = b || c = c ]]
	until [ $retries = "5" ]
	do
		if [ $(SH_Get_Build) != "0" ]; then
			# got a reponse

			# get sh build and version
			# into global variables
			SH_Build=$(SH_Get_Build)
			SH_Ver=$(SH_Get_Version)

			echo "Build: [$(ColorGreen "$SH_Build")]"
			echo "Version: [$(ColorGreen "$SH_Ver")]"

			# Experimental, check if update available and set global flag
			if [  $(SH_LatestBuild) != SH_Build ];  then
				SH_UpdateAvailable="1"
				echo "Update Available: [$(ColorGreen "$(SH_LatestBuild)")]"
			fi

			sleep 2
			return 0
		fi

		# just make sure we only stay in this loop so long
		((retries=retries+1))
		#Just sleep 2 sec
		sleep 2

	done

	# if the retries = 5 then just exit
	return 0
fi
}


# * SimpleHelp Backup Function                   
# *************************************************************
function SH_Backup () {

local sh_archive="0"
local sh_build=$(SH_AllVersions)
local sh_config="$install_dir/configuration/"
local tar_command="$backup_dir/$sh_archive.tar  configuration"

clear

echo "*----------------------------------------------------------------------------*"
echo "*  Backup..."
echo "*----------------------------------------------------------------------------*"
echo

until [  "$mnuChoice" = "F" ] || [  "$mnuChoice" = "f" ] || [  "$mnuChoice" = "C" ] || [  "$mnuChoice" = "c" ]
do
	read -p '(F)ull or (C)onfiguration: ' mnuChoice

	if [  "$mnuChoice" = "F" ] || [  "$mnuChoice" = "f" ]; then
		sh_archive="full_simplehelp_backup_v"$SH_Ver"_"$(date +"%Y%m%d_%H%M%S")
		tar_command="$full_backup_dir/$sh_archive.tar SimpleHelp"
	elif [  "$mnuChoice" = "C" ] || [  "$mnuChoice" = "c" ]; then
		sh_archive="simplehelp_backup_v"$SH_Ver"_"$(date +"%Y%m%d_%H%M%S")
		tar_command="$backup_dir/$sh_archive.tar  configuration"
	fi
done

clear

echo "*-------------------------------------**-------------------------------------*"
echo "*  Backup..."
echo "*----------------------------------------------------------------------------*"
echo -e "*  Backup Archive: [${colGreen}$sh_archive.tar${colEnd}]"
echo -e "*  Configuration Directory : [${colGreen}$sh_config${colEnd}]"
echo -e "*  Backup Directory: [${colGreen}$backup_dir${colEnd}]"
echo "*----------------------------------------------------------------------------*"
echo 
echo "Please wait.."

SH_ServiceStop

# save the current sh ver with backup
echo "Creating version file: $sh_archive.txt" 

# Change to the correct dir
# before backup
# **************************
if [  "$mnuChoice" = "F" ] || [  "$mnuChoice" = "f" ]; then
	echo "$sh_build" >> "$full_backup_dir/$sh_archive.txt"
	cd $install_dir/..
else
	echo "$sh_build" >> "$backup_dir/$sh_archive.txt"
	cd $install_dir
fi

echo "Creating archive: $sh_archive.tar" 
tar -cf $tar_command

SH_ServiceStart
echo 
return 1
}

# * SimpleHelp Restore Function
# *************************************************************
function SH_Restore () {

local validChoice=0
local sh_build=$(SH_AllVersions)
local sh_full_backup=0				# 0 = no / 1 = yes
local sh_create_backup=0			# 0 = no / 1 = yes
local sh_backup_root=""

until [  "$mnuChoice" = "F" ] || [  "$mnuChoice" = "f" ] || [  "$mnuChoice" = "C" ] || [  "$mnuChoice" = "c" ]
do
	clear

	echo "*----------------------------------------------------------------------------*"
	echo "*  Restore type..."
	echo "*----------------------------------------------------------------------------*"
	echo
	read -p '(F)ull or (C)onfiguration: ' mnuChoice

	if [  "$mnuChoice" = "F" ] || [  "$mnuChoice" = "f" ]; then
		sh_archive="full_simplehelp_backup_v"$SH_Ver"_"$(date +"%Y%m%d_%H%M%S")
		tar_command="$full_backup_dir/$sh_archive.tar SimpleHelp"
		sh_backup_root=$full_backup_dir
		sh_full_backup=1
	elif [  "$mnuChoice" = "C" ] || [  "$mnuChoice" = "c" ]; then
		sh_archive="simplehelp_backup_v"$SH_Ver"_"$(date +"%Y%m%d_%H%M%S")
		tar_command="$backup_dir/$sh_archive.tar  configuration"
		sh_backup_root=$backup_dir
		sh_full_backup=0
	fi
done

until [  "$mnuChoice" = "Y" ] || [  "$mnuChoice" = "y" ] || [  "$mnuChoice" = "N" ] || [  "$mnuChoice" = "n" ]
do
	clear

	echo "*----------------------------------------------------------------------------*"
	echo "*  Create backup before restore..."
	echo "*----------------------------------------------------------------------------*"
	echo 
	read -p '(Y)es (N)o: ' mnuChoice

	if [  "$mnuChoice" = "Y" ] || [  "$mnuChoice" = "y" ]; then
		sh_create_backup=1
	fi
done

until [  "$validChoice" = "1" ]
do
	clear

	n=1

	echo "*----------------------------------------------------------------------------*"
	echo "* Select backup to restore..."
	echo "*----------------------------------------------------------------------------*"

	for entry in "$sh_backup_root"/*.tar
	do
		echo "$n: $(basename ${entry})"
		#echo "  $n: $entry"
		#echo $n":" "$entry"
		#backups[$n]=$entry
		files[$n]="$entry"
		#arrayIndex=$n
		((n=n+1))
	done

	echo

	read -p 'Choose an option [1 - '$((n=n-1))']: '  mnuChoice

	fchoice=${files[$mnuChoice]}

	#echo $fchoice

	if [[ -n "$fchoice" ]];then
                #Exit loop if valid selection
		validChoice=1
	fi

done

until [  "$mnuChoice" = "Y" ] || [  "$mnuChoice" = "y" ] || [  "$mnuChoice" = "N" ] || [  "$mnuChoice" = "n" ]
do
	clear 

	echo "*----------------------------------------------------------------------------*"
	echo -e "*  Archive: [${colGreen} $(basename ${files[$mnuChoice]})${colEnd}]"
	#echo -e "*  Installation Dir: [${colGreen}$install_dir/configuration${colEnd}]"
	#echo -e "*  Configuration Backup Dir:  [${colGreen}$sh_backup_root${colEnd}]"
	echo "*----------------------------------------------------------------------------*"
	echo
	read -p 'Restore (Y)es or (N)o: ' mnuChoice
done

if [  "$mnuChoice" = "Y" ] || [  "$mnuChoice" = "y" ]; then

	SH_ServiceStop

	if [  "$sh_full_backup" = "1" ]; then
		cd $install_dir/..
	else
		cd $install_dir
	fi

	# save BACKUP to tar
	# **************************
	if [  "$sh_create_backup" = "1" ]; then
		# Save backup
		echo "Saving backup to: $sh_archive.tar"
		#echo "$sh_build" >> "$full_backup_dir/$sh_archive.txt"
		tar -cf $tar_command
	fi

	#  move current config
	echo "removing current installation..."
	#mv -R "$install_dir"/configuration/  "$install_dir"/

	# restore from backup
	echo "Restoring backup from archive..."
	#unzip -o ${files[$FileChoice]} -d $install_dir

	SH_ServiceStart

	echo
	read -p 'Press any key to continue... ' nullChoice
fi

return 1
}

function SH_Install_Upgrade () {
# * SimpleHelp Install and Upgrade Function
# *************************************************************

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

function SH_Get_Build () {

result="`wget -qO- http://127.0.0.1/allversions`"

if [ "$result" = "" ]; then
	echo "0"
	return 1
else
	echo "$result" | grep "SH Version" | awk '{print $3}' | sed s/"SSuite-"//
	return 0
fi

}

function SH_Get_Version {

result="`wget -qO- http://127.0.0.1/allversions`"

if [ "$result" = "" ]; then
	echo "0"
	return 1
else
	echo "$result" | grep "Visual Version" | awk '{print $3}'
	return 0
fi

}

# * SimpleHelp Latest Version Function
# *************************************************************
function SH_LatestBuild () {

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

# * SimpleHelp Service Status Function
# *************************************************************
function SH_ServiceStatus () {
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

# * SimpleHelp Service Start Function
# *************************************************************
function SH_ServiceStart () {
	if [ "$(SH_ServiceStatus)" = "yes" ]; then 
		#SH Already running
		echo "Already Running.."
		return 0
	elif [ "$(SH_ServiceStatus)" = "no" ]; then
		#Start SH
		echo "Starting Service..."
		cd "$install_dir"
		sh serverstart.sh >/dev/null 2>&1
		# wait until the server responds, before exit.
		until [ "$(SH_Get_Version)" != "0" ]
		do
			sleep 2
		done
		#sleep 5
		return 1
	fi
}

# * SimpleHelp Service Stop Function
# *************************************************************
function SH_ServiceStop () {
	if [ "$(SH_ServiceStatus)" = "yes" ]; then 
		#SH running, stop service
		echo "Stopping Service.."
		cd "$install_dir"
		sh serverstop.sh >/dev/null 2>&1
		# wait until the server syops responding, before exit.
		until [ "$(SH_Get_Version)" = "0" ]
		do
			sleep 2
		done
 		#sleep 15
		return 1
	elif [ "$(SH_ServiceStatus)" = "no" ]; then
		#Start SH
		echo "Service not running..."
		return 0
	fi
}

# * SimpleHelp SystemD Function
# *************************************************************
function SH_SystemD () {

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

# ************************************************
# * SimpleHelp Server helper script v1 MAIN MENU *
# ************************************************

SH_UpdateAvailable="0"

# do prequisites here first before displaying menus
# 1) check if sh running, if not show menu
# 2) if running try and get a response from server.
# 3) if response update global variables, then show menu.
SH_Prequisites

# save PID to pid file
# if this already exists in prequisites
# then were already running another instance.
############################################## 
echo $$ > "$sh_pid"

#echo "[ERROR]:$(ColorRed "$?") ------" >&2

# In a loop from here until x
until [  "$mnuChoice" = "X" ] || [  "$mnuChoice" = "x" ]
do
	clear

	#echo -e $(ColorBlue "Testing testing.....")
	echo "*----------------------------------------------------------------------------*"
	echo -e "*  SimpleHelp Server Tools v1"
	echo "*----------------------------------------------------------------------------*"
	echo -e "*  Install Dir: [${colGreen}$install_dir${colEnd}]	SH Build: [${colGreen}$SH_Build${colEnd}]"
	echo -e "*  Backup Dir : [${colGreen}$backup_dir${colEnd}]	SH Ver: [${colGreen}$SH_Ver${colEnd}]  SH Running: [${colGreen}$(SH_ServiceStatus)${colEnd}]"
	echo "*----------------------------------------------------------------------------*"
	echo ""
	echo "  1: Backup."
	echo "  2: Restore."

	# Show if update available, bit experimental
	if [ $SH_UpdateAvailable = "1" ];  then
		echo -e "  3: Install/Update. $colGreen[Update Available]$colEnd"
	elif [ $SH_UpdateAvailable = "0" ];  then
		echo "  3: Install/Update."
	fi

	echo "  4: Utilities."
	echo "  x: Exit."
	echo

	# read -p 'xx' -t 0.01 retval
	read -p 'Choose an option: ' mnuChoice

	# could stay in a loop with this
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
			sleep 4
		fi

		#echo "[ERROR]:$(ColorRed "$?") ------" >&2
		#sleep 4
done

trap "rm -f $sh_pid" EXIT
cd $initial_dir