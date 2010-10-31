#!/bin/bash
set -x
set -e

# Script to bootstrap vantrash installation on a EC2 instance

sudo apt-get install --assume-yes git-core screen nginx tmpreaper libxml2-dev libdb4.6-dev

cd $HOME
if [[ ! -d src ]]; then
    mkdir src
fi
cd src

if [[ ! -d dotdotdot ]]; then
	git clone git@github.com:lukec/dotdotdot.git
	rm dotdotdot/README
	mv dotdotdot/{.[A-z]*,*} $HOME
fi

if [[ ! -d vantrash ]]; then
	git clone git@github.com:lukec/vantrash.git
fi

