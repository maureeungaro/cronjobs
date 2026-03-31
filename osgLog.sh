#!/bin/zsh

src1="/volatile/clas12/osg/osgLog.json"
src2="/volatile/clas12/osg/osg-production.json"
src3="/volatile/clas12/osg/osg-devel.json"

dest="/u/group/clas/www/gemc/html/web_interface/data/"

cp "$src1" $src2" $src3" "$dest"
