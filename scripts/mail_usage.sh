#!/bin/bash

if [ -n "$1" ]
then
	ep statistics days range $(date +%m/%d/%Y -d '1 week ago')  $(date +%m/%d/%Y) | mailx -s "Energy usage report" $1   
else
	echo "No mail adress specified."
fi
