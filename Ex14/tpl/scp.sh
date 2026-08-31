#!/usr/bin/env bash

GEN_DIR=$(dirname "$0")/../gen

if [ $# -lt 2 ]; then
   echo usage: .../bin/scp ... ${devopsUsername}@${ip} ...
else
   scp -o UserKnownHostsFile="$GEN_DIR/known_hosts" $@
fi