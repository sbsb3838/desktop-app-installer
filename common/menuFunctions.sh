#!/bin/bash
##########################################################################
# This script contains menu functions used only by main script.
#
# Author: César Rodríguez González
# Version: 1.0
# Last modified date (dd/mm/yyyy): 07/05/2014
# Licence: MIT
##########################################################################

function menu {
	local appsToInstall=""
	local box=""	
	if [ -z $DISPLAY ]; then
		box="dialog"
	else
		box="zenity"
	fi
	# Check if dialog or zenity has been installed
	if [ "`dpkg -s $box 2>&1 | grep "installed"`" != "" ]; then
		# Delete blank and comment lines. Take category list (first column) and remove duplicated rows in appListFile content.
		local categoryArray=(`cat "$appListFile" | awk '!/^($|[:space:]*#)/{ print $1; }' | awk '!x[$0]++'`)
		local categoryName=""
		local categoryDescription=""
		local categoryNumber=1
		local totalCategoriesNumber=${#categoryArray[@]}
		local appsToInstall=""
		local selectedOptionsFile="$tempFolder/selectedOptions"
		local appNameArray=()
		local appNumber=0
		local command=""
		local appName=""
		local appDescription=""
		local selectedApps=""
		local index=1
		local zenityWidth=770
		local zenityHeight=0
		local maxZenityHeight=$((`xdpyinfo | grep dimensions | awk '{print $2}' | awk -F "x" '{print $2}'` - 100))

		for categoryName in "${categoryArray[@]}"; do
			# Each category has it's own screen
			eval categoryDescription=\$$categoryName"Description"
			# Delete blank and comment lines,then filter by category name and take application list (second column)
			appNameArray=(`cat "$appListFile" | awk -v category=$categoryName '!/^($|[:space:]*#)/{ if ($1 == category) print $2; }'`)
			appNumber=${#appNameArray[@]}
			index=1
	
			if [ -z $DISPLAY ]; then
				local dialogHeight=$(($appNumber+8))
				if [ $dialogHeight -gt $((`tput lines` - 5)) ]; then
					dialogHeight=$((`tput lines` - 5))
				fi
				command="dialog --title \"$mainMenuLabel\" --backtitle \"$linuxAppInstallerTitle\" --stdout --separate-output --checklist \"\n$categoryLabel $categoryNumber/$totalCategoriesNumber: $categoryDescription\" $dialogHeight $dialogWidth $appNumber "
			else
				zenityHeight=177
				if [ $appNumber -gt 2 ]; then
					zenityHeight=$(($zenityHeight+$(($(($appNumber-2))*27))))
					if [ $zenityHeight -gt $maxZenityHeight ]; then
						zenityHeight=$maxZenityHeight
					fi
				fi
				command="zenity --list --checklist --width=$zenityWidth --height=$zenityHeight --title=\"$linuxAppInstallerTitle\" --text \"$categoryLabel $categoryNumber/$totalCategoriesNumber: $categoryDescription\" --column \"$selection\" --column \"#\" --column=\"$value\" "
			fi
		
			for appName in "${appNameArray[@]}"; do
				# Indirect variable reference. Take value from variable <appName>Description
				eval appDescription=\$$appName"Description"
				if [ -z $DISPLAY ]; then
					command+="$index \"$appDescription\" off "
				else
					command+="off $index \"$appDescription\" "		
				fi
				index=$(($index+1))
			done
			eval "$command" > "$selectedOptionsFile"
			if [[ $? -ne 0 ]]; then
				# Exit the script
				exit 0
			fi
	
			if [ -z $DISPLAY ]; then
				selectedApps=`cat "$selectedOptionsFile"`	
			else
			selectedApps=`cat "$selectedOptionsFile" | tr '|' ' '`
			fi
		
			for option in $selectedApps; do
				index=$(($option-1))
				appsToInstall+="${appNameArray[$index]} "
			done
	
			categoryNumber=$(($categoryNumber+1))
		done
	fi
	echo "$appsToInstall"
}
