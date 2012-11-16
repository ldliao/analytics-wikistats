#!/bin/bash

ulimit -v 8000000

dataset2=dataset2::pagecounts-ez/wikistats
out=/a/wikistats/out

if [ "$1" == "" ] ; then
  echo "Project code missing! Specify as 1st argument one of wb,wk,wn,wp,wq,ws,wv,wx"
  exit
fi  

rm $out/zip_all/out_$1.zip

if [ "$1" == "wm" ] ; then
  cd $out/out_$1
else
  cd $out/out_$1/EN
fi

zip -q -r $out/zip_all/out_$1.zip *

exit
echo rsync -avv $out/zip_all/out_w*.zip $dataset2
rsync -avv $out/zip_all/out_w*.zip $dataset2



 

