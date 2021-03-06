#!/bin/sh

wikistats=/a/wikistats_git
backup=$wikistats/backup
dumps=$wikistats/dumps
csv=$dumps/csv

dt=$(date +[%Y-%m-%d][%H:%M])

cd $csv/zip_all
zip $backup/csv_full_$dt.zip *.zip

rsync -av $backup/*.zip  thorium.eqiad.wmnet::srv/wikistats/backup/
