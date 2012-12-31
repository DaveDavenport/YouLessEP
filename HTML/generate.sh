#!/bin/bash

EP=../ep


# months
$EP plot months png months.png

# Weeks
$EP plot weeks png weeks.png

# days
$EP plot days png days.png

#weekdays
$EP plot weekdays png weekdays.png

START=$(date +%m/%d/%Y -d '1 day ago')
STOP=$(date +%m/%d/%Y) 
$EP plot points range $START $STOP average png weekpoints.png

asciidoc energy.txt
