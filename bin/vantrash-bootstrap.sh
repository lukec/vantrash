#!/bin/bash
set -x

useradd vantrash
usermod -a -G www-data vantrash

set -e

# 
# Script to bootstrap vantrash installation on a EC2 instance
#

# First install core system dependencies
sudo apt-get install --assume-yes git-core nginx tmpreaper libxml2-dev \
        libdb4.6-dev ctags libssl-dev sqlite3 daemontools-run
# And some helper dev packages
sudo apt-get install --assume-yes screen multitail perl-doc

# Now install Perl dependencies
# First install cpanm for easy cpanning
curl -L http://cpanmin.us | perl - --sudo App::cpanminus

# Then install some missing dep
cpanm --sudo --force \
    Module::Install::ReadmeMarkdownFromPod

# Now get to the meat of our Perl dependiencies
cpanm --sudo \
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
    MooseX::Singleton \
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
    mocked \
    Plack

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

git config --global alias.co 'checkout'
git config --global color.ui true

