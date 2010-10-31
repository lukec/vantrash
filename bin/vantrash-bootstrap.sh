#!/bin/bash
set -x
set -e

# 
# Script to bootstrap vantrash installation on a EC2 instance
#

# First install core system dependencies
sudo apt-get install --assume-yes git-core screen nginx tmpreaper libxml2-dev libdb4.6-dev ctags

# Now install Perl dependencies
curl -L http://cpanmin.us | perl - --sudo App::cpanminus
cpanm --sudo  \
BerkeleyDB \
Crypt::DES \
DBIx::Class \
Data::ICal \
Data::UUID \
Date::ICal \
Email::MIME \
Email::MIME::Creator \
Email::Send \
Email::Send::Gmail \
Email::Valid \
JavaScript::Minifier::XS \
MRO::Compat \
Math::Polygon \
MooseX::Types \
MooseX::Types::Common::String \
Net::Twitter \
Socialtext::WikiObject \
Socialtext::WikiTest \
Template \
Test::HTTP \
URI::Encode \
WWW::Shorten \
WWW::Shorten::isgd \
WWW::Twilio::API \
Web::Scraper \
XML::XPath \
mocked

cd $HOME
if [[ ! -d src ]]; then
    mkdir src
fi
cd src

if [[ ! -d dotdotdot ]]; then
	git clone git@github.com:lukec/dotdotdot.git
	rm -f dotdotdot/README
	mv dotdotdot/{.[A-z]*,*} $HOME
        rm -rf dotdotdot
fi

if [[ ! -d vantrash ]]; then
	git clone git@github.com:lukec/vantrash.git
fi


