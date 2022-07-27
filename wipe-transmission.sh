#!/bin/bash

set -e
set -o pipefail

transmission-remote -l | grep -v ETA | grep -v Sum: | awk '{ print $1 }' | while read ID; do
	transmission-remote -t $ID -r
done
