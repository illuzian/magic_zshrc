# Name: Magic .zshrc for Ubuntu and OSX
# Updated: 2019-11-10
# Author: Anthony Hawkes
ANSI_WEATHER_KEY=''
export PATH=/usr/local/bin:$PATH
# Check if magicr  exist, if it does import the variable.
if [[ -f $HOME/.magicrc ]];then
	. $HOME/.magicrc
fi
# If user has not done this before, ask them for their details'
if [[ ! -v HAS_SUDO ]];then 
	while true; do
		read -q yn\?"Do you you have sudo access on this account? y/n:" 
		case $yn in
			[Yy]* ) HAS_SUDO=0; break;;
			[Nn]* ) HAS_SUDO=1; break;;
			* ) echo "Please answer y or n.";;
		 esac
	done
fi
# Install oh-my-zsh if it doesn't exist.
if [[ ! -d $HOME/.oh-my-zsh ]];then
	type git>/dev/null 2>/dev/null
	if [[ $? -eq 0 ]];then
		git clone https://github.com/robbyrussell/oh-my-zsh.git $HOME/.oh-my-zsh
	# If git not found throw error.
	elif [[ $? -eq 1 ]];then
		echo "ERROR: git not found, stopping rc file."
		return 10
	fi
fi
# Install antigen if it doesn't exist.
if [[ ! -f $HOME/antigen.zsh ]]; then
	type curl>/dev/null 2>/dev/null
	if [[ $? -eq 0 ]];then
		curl -L git.io/antigen > $HOME/antigen.zsh
	# If curl not found throw error.
	elif [[ $? -eq 1 ]];then
		echo "ERROR: curl not found, stopping processing."
		return 11
	fi
fi
# Import scripts.
export ZSH=$HOME/.oh-my-zsh
source $ZSH/oh-my-zsh.sh
source $HOME/antigen.zsh
# Selected cross platform modules.
antigen use oh-my-zsh
antigen bundle zsh-users/zsh-syntax-highlighting
antigen bundle fcambus/ansiweather
antigen theme agnoster
antigen bundle desyncr/auto-ls
antigen bundle unixorn/autoupdate-antigen.zshplugin
antigen bundle wting/autojump
antigen bundle colored-man-pages
antigen bundle jeanpantoja/dotpyvenv
antigen bundle oldratlee/hacker-quotes
antigen bundle skx/sysadmin-util

# Epochs set for 5 day intervals for apt-update and any future package manager.
AUTO_UPDATE_EPOCH=432000
NOW_EPOCH=$(date +%s)
# Commands to check and the packages to install to provide them.
typeset -A TO_INSTALL
TO_INSTALL=('bc' 'bc' 'jq' 'jq' 'gem' 'ruby' 'sqlite3' 'sqlite3')
# Package managers to iterate through.
typeset -A PACKAGE_MANAGERS
PACKAGE_MANAGERS=('brew' 'brew install' 'apt-get' 'sudo apt install')
SUPPORTED=1
# Check if we have a supported package manager.
for PKG_MAN in "${(@k)PACKAGE_MANAGERS}"; do
	# Check if OSX.
	uname -a | grep Darwin>/dev/null 2>/dev/null
	if [[ $? -eq 0 ]];then
		# If OSX and user has sudo install brew.
		type $PKG_MAN>/dev/null 2>/dev/null
		if [[ $? -eq 1 && $HAS_SUDO -eq 0 && $PKG_MAN = "brew" ]];then
			/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
		fi
	fi
	# Do the actual check.
	type $PKG_MAN>/dev/null 2>/dev/null
	if [[ $? -eq 0 ]];then
		SUPPORTED=0
	fi
done
# If not supported throw error.
if [[ $SUPPORTED -eq 1 ]]; then
	echo "ERROR: No supported package manager detected, exiting."
	return 13
fi
# We made it this far, moving through package managers.
for PKG_MAN in "${(@k)PACKAGE_MANAGERS}"; do
	type $PKG_MAN>/dev/null 2>/dev/null
	PMAN=$?
	# brew specific commands and installs.
	if [[ $PMAN -eq 0 && $PKG_MAN = "brew" ]]; then
		antigen bundle zsh-users/zsh-apple-touchbar
		antigen bundle sticklerm3/alehouse
		# Install exa.
		type exa>/dev/null 2>/dev/null
		if [[ $? -ne  0 ]]; then
			brew install exa
		fi
		# Show if there are outdated brew packages.
		BREW_OUTDATED=$(brew outdated | wc -l)
		if [[ $BREW_OUTDATED -gt 0 ]]; then
			echo "$BREW_OUTDATED brew packages out of date."
		fi
		# Check for and install coreutils.
		if [[ $(brew --cellar coreutils >/dev/null 2>/dev/null) -eq 1 ]]; then
                	brew install coreutils
     		fi
	fi

	# apt specific commands and installs.
	if [[ $PMAN = 0 && $PKG_MAN = "apt-get" ]]; then
		# Install exa if user has sudo.
		type exa>/dev/null 2>/dev/null
		if [[ $? -ne 0  && $HAS_SUDO -eq  0 ]]; then
			EXA_LATEST=`curl --silent "https://api.github.com/repos/ogham/exa/releases/latest" |  grep '"browser_download_url":' | grep -i "linux" |  sed -E 's/.*"([^"]+)".*/\1/'`
			wget $EXA_LATEST -O /tmp/exa.zip
			unzip /tmp/exa.zip -d /tmp
			EXA_NAME=`ls /tmp | grep  exa-linux`
			sudo mv /tmp/$EXA_NAME /usr/bin/exa
			sudo chmod ugoa+x /usr/bin/exa
		elif [[ $HAS_SUDO -eq 1 ]]; then
			echo "NO SUDO: Installing exa(ls replacement) was skipped." 
		fi

		# Get apt's last apt update epoch.
		if [[ -e /var/lib/apt/periodic/update-success-stamp ]];then
			LAST_UPDATE_EPOCH=$(stat -c %X /var/lib/apt/periodic/update-success-stamp)
			# Check how long it was since last update.
			EPOCH_DIFF=($NOW_EPOCH - $LAST_UPDATE_EPOCH)
			if [[ $EPOCH_DIFF -gt $AUTO_UPDATE_EPOCH  && $HAS_SUDO -eq 0 ]]; then
				echo "Time to update apt sources."
				sudo apt update
			elif [[ $HAS_SUDO -eq 1 ]]; then
				echo "NO SUDO: last apt update check was skipped"
			fi
		fi

		# Check if there are any packages available to update. Probably only works on Ubuntu.
		if [[ -f /usr/lib/update-notifier/apt-check && $HAS_SUDO -eq 0 ]]; then
			IFS=';' read APT_UPDATES APT_SECURITY_UPDATES < <(/usr/lib/update-notifier/apt-check 2>&1)
			if [[ ( APT_UPDATES -gt 0 || APT_SECURITY_UPDATES -gt 0 ) ]]; then
				echo "Installing updates."
				sudo apt upgrade
			fi
		elif [[ $HAS_SUDO -eq 1 ]]; then
			echo "NO SUDO: login update check and install skipped"
		fi
		# Check for and install coreutils.
		if [[ $(dpkg-query --show coreutils gem >/dev/null 2>/dev/null) -eq 1 && $HAS_SUDO -eq 0 ]]; then
        		sudo apt install coreutils
		elif [[ $HAS_SUDO -eq 1 ]]; then
			echo "NO SUDO: not trying to install coreutils."
		fi
	fi

	# Iterate through the packages required for some of the zsh plugins.
	if [[ $PMAN = 0 && $HAS_SUDO -eq 0 ]]; then
		for PKG_INSTALL in "${(@k)TO_INSTALL}"; do
			type $PKG_INSTALL>/dev/null 2>/dev/null
			if [[ $? != 0 ]]; then
				eval "$PACKAGE_MANAGERS[[$PKG_MAN]] $TO_INSTALL[[$PKG_INSTALL]]"
			fi	
		done
	elif [[ $HAS_SUDO -eq 1 ]]; then
		echo "NO SUDO: Not trying to install required plugin packages. This might cause problems."
	fi
	
done
# Enable add-zsh-hook.
autoload -Uz add-zsh-hook
# If user has sqlite3 enable histdb.
type sqlite3 >/dev/null 2>/dev/null
if [[ $? -eq 0 ]]; then 
	antigen bundle larkery/zsh-histdb
	add-zsh-hook precmd histdb-update-outcome
	source $HOME/.antigen/bundles/larkery/zsh-histdb/sqlite-history.zsh
fi
# Configure ansiweather plugin.


# This is how we like it.
CASE_SENSITIVE="true"

antigen apply

# Alias ls to exa if it exists.
type exa>/dev/null 2>/dev/null
if [[ $? -eq 0 ]]; then
	alias ls='exa'
fi
if [[ ! -f $HOME/.ansiweatherrc ]]; then
	printf '%s\n' 'location:Perth,AU' 'units:metric' 'show_daylight:true' "api_key:$ANSI_WEATHER_KEY" > $HOME/.ansiweatherrc
fi
# Show the weather.
if [[ ! -e $HOME/.magicrc ]];then
	if [[ $HAS_SUDO -eq 0 ]];then
		printf 'export HAS_SUDO=0' > $HOME/.magicrc
		echo "Set HAS_SUDO=0 (true) in $HOME/.magicrc"
	elif [[ $HAS_SUDO -eq 1 ]];then
		printf 'export HAS_SUDO=1' > $HOME/.magicrc
		echo "Set HAS_SUDO=1 (false) in $HOME/.magicrc"
		echo "If you later get sudo you can edit this file and change HAS_SUDO to 0 or simply delete $HOME/.magicrc"
	fi

	chmod +x $HOME/.magicrc
fi

$HOME/.antigen/bundles/fcambus/ansiweather/ansiweather
