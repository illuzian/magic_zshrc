# Name: Magic .zshrc for Ubuntu and OSX
# Updated: 2019-11-10
# Author: Anthony Hawkes

export PATH=/usr/local/bin:$PATH

# Install oh-my-zsh if it doesn't exist.
if [ ! -d $HOME/.oh-my-zsh ]; then
	git clone https://github.com/robbyrussell/oh-my-zsh.git $HOME/.oh-my-zsh
fi
# Install antigen if it doesn't exist.
if [ ! -f $HOME/antigen.zsh ]; then
	curl -L git.io/antigen > $HOME/antigen.zsh
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
# antigen bundle wulfgarpro/history-sync # https://github.com/wulfgarpro/history-sync

# Epochs set for 5 day intervals for apt-update and any future package manager.
AUTO_UPDATE_EPOCH=432000
NOW_EPOCH=$(date +%s)
# Commands to check and the packages to install to provide them.
typeset -A TO_INSTALL
TO_INSTALL=('bc' 'bc' 'jq' 'jq' 'gem' 'ruby' 'sqlite3' 'sqlite3')
# Package managers to iterate through.
typeset -A PACKAGE_MANAGERS
PACKAGE_MANAGERS=('brew' 'brew install' 'apt-get' 'sudo apt install')

for PKG_MAN in "${(@k)PACKAGE_MANAGERS}"; do

	type $PKG_MAN>/dev/null 2>/dev/null
	PMAN=$?

	# brew specific commands and installs.
	if [[ $PMAN = 0 && $PKG_MAN = "brew" ]]; then
		antigen bundle zsh-users/zsh-apple-touchbar
		antigen bundle sticklerm3/alehouse
		# Install exa.
		type exa>/dev/null 2>/dev/null
		if [ $? != 0 ]; then
			brew install exa
		fi
		# Show if there are outdated brew packages.
		BREW_OUTDATED=$(brew outdated | wc -l)
		if [ $BREW_OUTDATED -gt 0 ]; then
			echo "$BREW_OUTDATED brew packages out of date."
		fi
		# Check for and install coreutils.
		if [ ! brew --cellar coreutils>/dev/null 2>/dev/null ]; then
                brew install coreutils
     	fi
	fi

	# apt specific commands and installs.
	if [[ $PMAN = 0 && $PKG_MAN = "apt" ]]; then

		# Install exa.
		type exa>/dev/null 2>/dev/null
		if [ $? != 0 ]; then
			ec
			EXA_LATEST=`curl --silent "https://api.github.com/repos/ogham/exa/releases/latest" |  grep '"browser_download_url":' | grep -i "linux" |  sed -E 's/.*"([^"]+)".*/\1/'`
			wget $EXA_LATEST -O /tmp/exa.zip
			unzip /tmp/exa.zip -d /tmp
			EXA_NAME=`ls /tmp | grep  exa-linux`
			sudo mv /tmp/$EXA_NAME /usr/bin/exa
			sudo chmod agou+rx /usr/bin/exa
		fi
		#antigen bundle trapd00r/LS_COLORS

		# Get apt's last apt update epoch.
		LAST_UPDATE_EPOCH=$(stat -c %X /var/lib/apt/periodic/update-success-stamp)

		# Check how long it was since last update.
		if [ $(($NOW_EPOCH - $LAST_UPDATE_EPOCH)) -gt $AUTO_UPDATE_EPOCH ]; then
			echo "Time to update apt sources."
  			sudo apt update
		fi

		# Check if there are any packages available to update. Probably only works on Ubuntu.
		if [ -f /usr/lib/update-notifier/apt-check ]; then
			IFS=';' read APT_UPDATES APT_SECURITY_UPDATES < <(/usr/lib/update-notifier/apt-check 2>&1)
			if [[ ( APT_UPDATES -gt 0 || APT_SECURITY_UPDATES -gt 0 ) ]]; then
				echo "Installing updates."
				sudo apt upgrade
			fi
		fi
		# Check for and install coreutils.
		if [ ! dpkg-query --show coreutils gem >/dev/null 2>/dev/null ]; then
        	sudo apt install coreutils
    	fi
	fi

	# Iterate through the packages required for some of the zsh plugins.
	if [ $PMAN = 0 ]; then
		for PKG_INSTALL in "${(@k)TO_INSTALL}"; do
			type $PKG_INSTALL>/dev/null 2>/dev/null
			if [ $? != 0 ]; then
				eval "$PACKAGE_MANAGERS[$PKG_MAN] $TO_INSTALL[$PKG_INSTALL]"
			fi	
		done
	fi
	
done

# type colorls>/dev/null 2>/dev/null
# if [ $? != 0 ]; then
# 	gem install colorls
# fi
antigen bundle larkery/zsh-histdb
#antigen bundle gretzky/auto-color-ls

# Configure ansiweather plugin.
if [ ! -f $HOME/.ansiweatherrc ]; then
	printf '%s\n' 'location:Perth,AU' 'units:metric' 'show_daylight:true' 'api_key:' > $HOME/.ansiweatherrc
fi

# This is how we like it.
CASE_SENSITIVE="true"

# Configure zsh-histdb.
autoload -Uz add-zsh-hook
add-zsh-hook precmd histdb-update-outcome
antigen apply

# Alias ls to exa.
alias ls='exa -la'
# ZSH_HISTORY_FILE_NAME=".zsh_history"
# ZSH_HISTORY_FILE="${HOME}/${ZSH_HISTORY_FILE_NAME}"
# ZSH_HISTORY_PROJ="${HOME}/.zsh_history_proj"
# ZSH_HISTORY_FILE_ENC_NAME="zsh_history"
# ZSH_HISTORY_FILE_ENC="${ZSH_HISTORY_PROJ}/${ZSH_HISTORY_FILE_ENC_NAME}"
# GIT_COMMIT_MSG="latest $(date)"

# Enable zsh-histdb.
source $HOME/.antigen/bundles/larkery/zsh-histdb/sqlite-history.zsh
# Show the weather.
$HOME/.antigen/bundles/fcambus/ansiweather/ansiweather
