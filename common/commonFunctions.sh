#!/bin/bash
##########################################################################
# This script contains common functions used by installation scripts
# @author 	César Rodríguez González
# @since 	1.0, 2014-05-10
# @version 	1.3, 2016-08-12
# @license 	MIT
##########################################################################

##
# This function show a initial credits dialog box or popup message
# @since 	v1.3
##
function credits
{
	if [ -z $DISPLAY ]; then
		local whiteSpaces="                  "
		printf "\n%.21s%s\n" "$scriptNameLabel:$whiteSpaces" "$linuxAppInstallerTitle" > $tempFolder/linux-app-installer.credits
		printf "%.21s%s\n" "$scriptDescriptionLabel:$whiteSpaces" "$scriptDescription" >> $tempFolder/linux-app-installer.credits
		printf "%.21s%s\n" "$testedOnLabel:$whiteSpaces" "$testedOnDistros" >> $tempFolder/linux-app-installer.credits
		printf "%.21s%s\n" "$githubProjectLabel:$whiteSpaces" "$githubProjectUrl" >> $tempFolder/linux-app-installer.credits
		printf "%.21s%s\n" "$authorLabel:$whiteSpaces" "$author" >> $tempFolder/linux-app-installer.credits
		dialog --title "$creditsLabel" --backtitle "$linuxAppInstallerTitle" --stdout --textbox $tempFolder/linux-app-installer.credits 11 100
	else
			notify-send -i "$installerIconFolder/tux96.png" "$linuxAppInstallerTitle" "$scriptDescription\n$testedOnLabel\n$testedOnDistrosLinks" -t 10000
	fi
}


##
# This funtion installs dialog or zenity packages, if not installed yet,
# according to detected enviroment: desktop or terminal
# @since v1.0
##
function installNeededPackages
{
	if [ -z $DISPLAY ]; then
		if [ -z "`dpkg -s dialog 2>&1 | grep "installed"`" ]; then
			echo "$installingRepoApplication Dialog"
			sudo apt-get -y install dialog --fix-missing
		fi
	else
		local neededPackages sudoHundler sudoOption sudoPackage
		if [ "$KDE_FULL_SESSION" != "true" ]; then
			sudoHundler="gksudo"; sudoOption="-S"; sudoPackage="gksu"
		else
			sudoHundler="kdesudo"; sudoOption="-c"; sudoPackage="kdesudo"
		fi
		if [ -z "`dpkg -s $sudoPackage 2>&1 | grep "installed"`" ]; then
			echo "$installingRepoApplication $sudoPackage"
			sudo apt-get -y install $sudoPackage --fix-missing
		fi
		if [ -z "`dpkg -s zenity 2>&1 | grep "installed"`" ]; then
			neededPackages+="zenity"
		fi
		if [ -z "`dpkg -s libnotify-bin 2>&1 | grep "installed"`" ]; then
			if [ -n "$neededPackages" ]; then neededPackages+=" "; fi
			neededPackages+="libnotify-bin"
		fi
		if [ "$distro" == "ubuntu" ] && [ "$KDE_FULL_SESSION" == "true" ]; then
			# KDE needs to install Debconf dependencies.
			if [ -z "`dpkg -s libqtgui4-perl 2>&1 | grep "installed"`" ]; then
				if [ -n "$neededPackages" ]; then neededPackages+=" "; fi
				neededPackages+="libqtgui4-perl"
			fi
		fi
		if [ -n "$neededPackages" ]; then
			`$sudoHundler $sudoOption "apt-get -y install $neededPackages" 1>/dev/null 2>>"$logFile"`
		fi
	fi
}

##
# This funtion sets application log file
# @since 	v1.3
# @param  String scriptPath Folder path to access main script root folder
# @return String 						path and log filename
##
function getLogFilename
{
	local scriptPath="$1"
	local splittedPath
	IFS='/' read -ra splittedPath <<< "$scriptPath"
	local numberItemsPath=${#splittedPath[@]}
	local scriptName=${splittedPath[$(($numberItemsPath-1))]}
	echo "${scriptName/.sh/}-$snapshot.log"
}

##
# This funtion prepares main installer script to be executed
# Creates needed folders and files used by installation script
# @since v1.0
##
function prepareScript
{
	logFilename=$( getLogFilename "$1" )
	logFile="$logsFolder/$logFilename"
	# Create temporal folders and files
	mkdir -p "$tempFolder" "$logsFolder"
	rm -f "$logFile"
	installNeededPackages
	echo -e "$linuxAppInstallerTitle\n========================" > "$logFile"

	credits
}

##
# This function gets all existing subscripts that matches following requisites:
# 1. Filename must be: appName.sh / appName_x64.sh / appName_i386.sh
# 2. Filename must match O.S. arquitecture (*_i386 32bits / *_x64 64bits / other all)
# 3. Must be placed in targetFolder or the subfolder that matchs your linux distro
# @since 	v1.3
# @param 	String targetFolder	Root scripts folder
# @param 	String appName			Name of an application
# @result String 							List of path/filename of found subscripts
##
function getAppSubscripts
{
	if [ -z "$1" ] || [ -z "$2" ]; then
		echo ""			# All parameters are mandatories
	else
		local targetFolder="$1" appName="$2"
		local i386="_i386" x64="_x64" subscriptList
		# Search subscript that matches all O.S. architecture
		if [ -f "$targetFolder/$appName.sh" ]; then subscriptList+="$targetFolder/$appName.sh "; fi
		if [ -f "$targetFolder/$distro/$appName.sh" ]; then subscriptList+="$targetFolder/$distro/$appName.sh "; fi
		if [ `uname -m` == "x86_64" ]; then
			# Search subscript that matches 64 bits O.S. architecture
			if [ -f "$targetFolder/$appName$x64.sh" ]; then subscriptList+="$targetFolder/$appName$x64.sh "; fi
			if [ -f "$targetFolder/$distro/$appName$x64.sh" ]; then subscriptList+="$targetFolder/$distro/$appName$x64.sh "; fi
		else
			# Search subscript that matches 32 bits O.S. architecture
			if [ -f "$targetFolder/$appName$i386.sh" ]; then subscriptList+="$targetFolder/$appName$i386.sh "; fi
			if [ -f "$targetFolder/$distro/$appName$i386.sh" ]; then subscriptList+="$targetFolder/$distro/$appName$i386.sh "; fi
		fi
		echo "$subscriptList"
	fi
}

##
# This function generates bash commands to execute a specified subscript during
# installation process. The subscript can be referenced by an application name
# or directly by script-name.sh
# @since 	v1.3
# @param String targetFolder	Destination folder where is placed the script [mandatory]
# @param String name				 	Name of application or subscript to be executed [mandatory]
#		- if name=identifier is considered as an application name
#		- if name=identifier.sh is considered as a subscript filename
# @param String message				Message to be showed in box/window [mandatory]
# @param String argument			Argument passed to name script [optional]
# @return String 							list of bash shell commands separated by ;
##
function generateCommands
{
	if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
		echo ""			# First three parameters are mandatories
	else
		# Get parameters and initialize variables
		local targetFolder="$1" message="$3" commands messageCommand argument appName
		if [[ "$2" == *.sh ]]; then			# Name is a script filename
			if [ -f "$targetFolder/$2" ]; then
				argument="$4"
				messageCommand="echo \"# $  $message: $argument\"; echo \"$  $message: $argument\" >> \"$logFile\";"
				commands="bash \"$targetFolder/$2\" \"$scriptRootFolder\" \"$username\" \"$homeFolder\" \"$argument\" 2>>\"$logFile\";"
			fi
		else														# Name is an application name
			appName="$2"
			local scriptList=( $( getAppSubscripts "$targetFolder" "$appName" ) )
			# Iterate through all subscript files
			for script in "${scriptList[@]}"; do
				commands+="bash \"$script\" \"$scriptRootFolder\" \"$username\" \"$homeFolder\" 2>>\"$logFile\";"
				messageCommand+="echo \"# $  $message: $appName\"; echo \"$  $message: $appName\" >> \"$logFile\";"
			done
		fi
		if [ -n "$commands" ]; then echo "$messageCommand $commands"; else echo ""; fi
	fi
}

##
# This function execute all commands associated to one installation step
# @since v1.3
# @param String							stepName	Name of the Step. Key of commandsPerInstallationStep map [mandatory]
# @param String							message		Message to display on box / window [mandatory]
# @param int 								stepIndex	Index of current step during installation process [global]
# @param Map<String,String> commandsPerInstallationStep 	Shell commands per installation steps [global]
# 	Keys of installation steps are:
# 		commandsDebconf				First step. Commands to setup interface to show terms of application
# 		thirdPartyRepo				Second step. Commands to add all third-party repositories needed
# 		preInstallation				Third step. Commands to prepare installation of some applications
# 		updateRepo						Fouth step. Commands to update repositories
# 		installRepoPackages		Fifth step. Commands to install applications from repositories
# 		installNonRepoApps		Sixth step. Commands to install non-repository applications
#		  eulaApp								Seventh step (only terminal mode). Commands to install apps with eula
# 		postInstallation			Next step. Commands to setup some applications to be ready to use
# 		finalOperations				Final step. Final operations: clean packages, remove temp.files, etc
##
function executeStep
{
	local stepName="$1"	message="$step $stepIndex: $2"

	if [ ${#commandsPerInstallationStep[$stepName]} -gt 0 ]; then
		if [ -z $DISPLAY ]; then
			if [ "$stepName" != "eulaApp" ]; then
				clear; sudo bash -c "${commandsPerInstallationStep[$stepName]}" | dialog --title "$message" --backtitle "$linuxAppInstallerTitle" --progressbox $dialogHeight $dialogWidth
			else
				clear; echo "\n$message\n\n"; sudo bash -c "${commandsPerInstallationStep[eulaApp]}"
			fi
		else
			local autoclose=""
			if [ "$stepName" != "installNonRepoApps" ]; then autoclose="--auto-close"; fi
			( SUDO_ASKPASS="$commonFolder/askpass.sh" sudo -A bash -c "${commandsPerInstallationStep[$stepName]}" ) | zenity --progress --title="$message" --no-cancel --pulsate $autoclose --width=$zenityWidth --window-icon="$installerIconFolder/tux32.png"
		fi
		stepIndex=$(($stepIndex+1))
	fi
}

##
# This function show logs after installation process
##
function showLogs
{
	if [ -z $DISPLAY ]; then
		dialog --title "Log. $pathLabel: $logFile" --backtitle "$linuxAppInstallerTitle" --textbox "$logFile" $dialogHeight $dialogWidth
	else
		local logMessage="$folder\n<a href='$logsFolder'>$logsFolder</a>\n$file\n<a href='$logFile'>$logFilename</a>"
		notify-send -i "$installerIconFolder/logviewer.svg" "$logNotification" "$logMessage" -t 10000
		zenity --text-info --title="$linuxAppInstallerTitle Log" --filename="$logFile" --width=$zenityWidth --height=$zenityHeight --window-icon="$installerIconFolder/tux32.png"
	fi
	chown $username:$username "$logFile"
}

##
# This funtion executes commands to install a set of applications
# @param int totalRepoAppsToInstall			Number of repo apps to install
# @param int totalNonRepoAppsToInstall	Number of non-repo apps to install
# @param int totalEulaAppsToInstall			Number of eula apps to install
# @since v1.0
##
function executeCommands
{
	local totalRepoAppsToInstall=$1 totalNonRepoAppsToInstall=$2 totalEulaAppsToInstall=$3

	# sudo remember always password
	sudo cp -f "$etcFolder/desktop-app-installer-sudo" /etc/sudoers.d/
	executeStep "commandsDebconf" "$settingDebconfInterface"
	executeStep "thirdPartyRepo" "$addingThirdPartyRepos"
	executeStep "preInstallation" "$preparingInstallationApps"
	executeStep "updateRepo" "$updatingRepositories"
	executeStep "installRepoPackages" "$installingRepoApplications $totalRepoAppsToInstall"
	executeStep "installNonRepoApps" "$installingNonRepoApplications $totalNonRepoAppsToInstall"
	executeStep "eulaApp" "$installingEulaApplications $totalEulaAppsToInstall"
	executeStep "postInstallation" "$settingUpApplications"
	executeStep "finalOperations" "$cleaningTempFiles"
	echo "# $installationFinished"; echo -e "$installationFinished\n========================" >> "$logFile"
	showLogs
	sudo rm -f /etc/sudoers.d/app-installer-sudo
}

##
# This funtion generates and executes bash commands to install a
# set of applications
# @since v1.0
# @param String[] appsToInstall	 List of applications to be installed
##
function installAndSetupApplications
{
	local appsToInstall=("${!1}")
	if [ ${#appsToInstall[@]} -gt 0 ]; then
		local totalAppsNumber=${#appsToInstall[@]} indexRepoApps=0 indexNonRepoApps=0 indexEulaApps=0 appName commands nonRepoScriptList

		if [ -n $DISPLAY ]; then notify-send -i "$installerIconFolder/applications-other.svg" "$installingSelectedApplications" "" -t 10000; fi
		for appName in ${appsToInstall[@]}; do
			commandsPerInstallationStep[thirdPartyRepo]+=$( generateCommands "$thirdPartyRepoFolder" "$appName" "$addingThirdPartyRepo" )
			commandsPerInstallationStep[preInstallation]+=$( generateCommands "$preInstallationFolder" "$appName" "$preparingInstallationApp" )
			if [ -f "$eulaFolder/$appName" ]; then
				indexEulaApps=$(($indexEulaApps+1))
				commandsPerInstallationStep[eulaApp]+=$( generateCommands "$commonFolder" "installapp.sh" "$installingEulaApplication $indexEulaApps" "$appName" )
			else
				nonRepoScriptList=( $( getAppSubscripts "$nonRepositoryAppsFolder" "$appName" ) )
				if [ ${#nonRepoScriptList[@]} -gt 0 ] ; then
					indexNonRepoApps=$(($indexNonRepoApps+1))
					commandsPerInstallationStep[installNonRepoApps]+=$( generateCommands "$nonRepositoryAppsFolder" "$appName" "$installingNonRepoApplication $indexNonRepoApps" )
				else
					indexRepoApps=$(($indexRepoApps+1))
					commandsPerInstallationStep[installRepoPackages]+=$( generateCommands "$commonFolder" "installapp.sh" "$installingRepoApplication $indexRepoApps" "$appName" )
				fi
			fi
			commandsPerInstallationStep[postInstallation]+=$( generateCommands "$postInstallationFolder" "$appName" "$settingUpApplication" )
			appIndex=$(($appIndex+1))
		done

		if [ $indexRepoApps -gt 0 ] || [ $indexNonRepoApps -gt 0 ] || [ $indexEulaApps -gt 0 ]; then
			commandsPerInstallationStep[commandsDebconf]=$( generateCommands "$commonFolder" "setupDebconf.sh" "$settingDebconfInterface" )
			if [ -n "${commandsPerInstallationStep[thirdPartyRepo]}" ] || [ -n  "${commandsPerInstallationStep[preInstallation]}" ]; then
				commandsPerInstallationStep[updateRepo]=$( generateCommands "$commonFolder" "updateRepositories.sh" "$updatingRepositories" )
			fi
			commandsPerInstallationStep[finalOperations]=$( generateCommands "$commonFolder" "finalOperations.sh" "$cleaningTempFiles" )
			executeCommands $indexRepoApps $indexNonRepoApps $indexEulaApps
		fi
	fi
	if [ -n $DISPLAY ]; then notify-send -i "$installerIconFolder/octocat96.png" "$githubProject" "$githubProjectLink\n$linuxAppInstallerAuthor" -t 10000; fi
}
