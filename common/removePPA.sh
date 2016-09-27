#!/bin/bash
##########################################################################
# This script removes a third party repository of an application through a
# specific PPA
# @author 	César Rodríguez González
# @since 	1.3, 2016-09-26
# @version 	1.3, 2016-09-26
# @license 	MIT
##########################################################################

# Check if the script is being running by a root or sudoer user
if [ "$(id -u)" != "0" ]; then echo "" 1>&2; echo "This script must be executed by a root or sudoer user" 1>&2; echo "" 1>&2; exit 1; fi

# Parameters
if [ -n "$1" ]; then scriptRootFolder="$1"; else scriptRootFolder="`pwd`/.."; fi
if [ -n "$2" ]; then username="$2"; else username="`whoami`"; fi
if [ -n "$3" ]; then homeFolder="$3"; else homeFolder="$HOME"; fi
if [ -n "$4" ]; then
  ppa="$4"
  # Add common variables
  . $scriptRootFolder/common/commonVariables.properties
  if [ -z "$DISPLAY" ]; then
    add-apt-repository -ry $ppa
  else
    xterm -T "$terminalProgress. PPA: $ppa" \
      -fa 'DejaVu Sans Mono' -fs 11 \
      -geometry 200x15+0-0 \
      -xrm 'XTerm.vt100.allowTitleOps: false' \
      -e "add-apt-repository -ry $ppa"
  fi
fi
