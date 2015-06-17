#!/usr/bin/env bash

# ?: why do you call "dea next gems" if it is also used in CC 
# ?: why do we need ruby 1.9.2
# rvm install 1.9.2
# rvm install 2.1.2
# rvm use 1.9.2

# Target: dea_next_gems_vendor_cache.tar.gz
# This archive includes: 
#  - eventmachine-1.0.3.gem
#  - nokogiri-1.6.6.2.gem
#  - nokogiri-1.6.3.1.gem
#  - nokogiri-1.6.2.1.gem
#  - ffi-1.9.3.gem

# wget -O nokogiri-1.6.2.1.tar.gz https://github.com/sparklemotion/nokogiri/archive/v1.6.2.1.tar.gz
# wget -O nokogiri-1.6.3.1.tar.gz https://github.com/sparklemotion/nokogiri/archive/v1.6.3.1.tar.gz
# wget -O nokogiri-1.6.6.2.tar.gz https://github.com/sparklemotion/nokogiri/archive/v1.6.6.2.tar.gz
# wget ftp://ftp.xmlsoft.org/libxml2/libxml2-2.8.0.tar.gz
# wget ftp://ftp.xmlsoft.org/libxml2/libxslt-1.1.28.tar.gz
# wget -O eventmachine-0.12.10.tar.gz https://github.com/eventmachine/eventmachine/archive/v0.12.10.tar.gz
# wget -O ffi-1.9.3.tar.gz https://github.com/ffi/ffi/archive/1.9.3.tar.gz

set -xe

scripts_folder=/home/ubuntu/binary-builder/bin
username=ubuntu
blobs_folder=/home/ubuntu/cf-release/blobs
source $scripts_folder/helpers.sh
mkdir -p $build_package/dea_next_gems/vendor/cache

rvm use system
gem install rake-compiler

target_folder=$build_package/dea_next_gems/vendor/cache
mkdir -p $target_folder

# nokogiri-1.6.2.1
set_environment_variables nokogiri '1.6.2.1'
unarchive_package
go_to_build_folder
patch -p1 < $assets_folder/dea_next_gems/nokogiri.patch
gem install bundler
bundle install
rake gem # or rake gem:package
cp pkg/$full_package_name.gem $target_folder

# eventmachine-0.12.10
set_environment_variables eventmachine '0.12.10'
unarchive_package
go_to_build_folder
patch -p1 < $assets_folder/dea_next_gems/eventmachine.patch
gem build eventmachine.gemspec
cp $full_package_name.gem $target_folder

# ffi-1.9.3

set_environment_variables ffi '1.9.3'
unarchive_package
go_to_build_folder
patch -p1 < $assets_folder/dea_next_gems/ffi.patch
rvm use 2.1.4
rake
cp $full_package_name.gem $target_folder

cd $build_package/dea_next_gems
tar -czvf $blobs_folder/dea_next_gems/dea_next_gems_vendor_cache.tar.gz ./**/*
