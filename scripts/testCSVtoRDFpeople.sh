#!/bin/bash

# Copyright (c) 2010 Christopher Haines, Dale Scheppler, Nicholas Skaggs, Stephen V. Williams.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the new BSD license
# which accompanies this distribution, and is available at
# http://www.opensource.org/licenses/bsd-license.html
# 
# Contributors:
#     Christopher Haines, Dale Scheppler, Nicholas Skaggs, Stephen V. Williams, James Pence- initial API and implementation

# Exit on first error
set -e

# Set working directory
HARVESTERDIR=`dirname "$(cd "${0%/*}" 2>/dev/null; echo "$PWD"/"${0##*/}")"`
HARVESTERDIR=$(cd $HARVESTERDIR; cd ..; pwd)

HARVESTER_TASK=csv

if [ -f scripts/env ]; then
  . scripts/env
else
  exit 1
fi
echo "Full Logging in $HARVESTER_TASK_DATE.log"

# Setting variables for cleaner script lines.
#Base data directory
BASEDIR=harvested-data/$HARVESTER_TASK

#data directories
RAWCSVDIR=$BASEDIR/csv
RAWRHDIR=$BASEDIR/rh-raw
RDFRHDIR=$BASEDIR/rh-rdf
MODELDIR=$BASEDIR/model
SCOREDATADIR=$BASEDIR/score-data

#model database urls
RAWCSVDBURL=jdbc:h2:$RAWCSVDIR/store
RAWRHDBURL=jdbc:h2:$RAWRHDIR/store
RDFRHDBURL=jdbc:h2:$RDFRHDIR/store
MODELDBURL=jdbc:h2:$MODELDIR/store
SCOREDATADBURL=jdbc:h2:$SCOREDATADIR/store
MATCHEDDBURL=jdbc:h2:$SCOREDATADIR/match

#model names
CSVMODELNAME=csvRawData
MODELNAME=csvTempTransfer
SCOREDATANAME=csvScoreData
MATCHEDNAME=csvTempMatch

#temporary copy directory
TEMPCOPYDIR=$BASEDIR/temp-copy

#scoring data models
SCOREINPUT="-i $H2MODEL -ImodelName=$MODELNAME -IdbUrl=$MODELDBURL -IcheckEmpty=$CHECKEMPTY"
SCOREDATA="-s $H2MODEL -SmodelName=$SCOREDATANAME -SdbUrl=$SCOREDATADBURL -ScheckEmpty=$CHECKEMPTY"
SCOREMODELS="$SCOREINPUT -v $VIVOCONFIG -VcheckEmpty=$CHECKEMPTY $SCOREDATA -t $TEMPCOPYDIR -b $SCOREBATCHSIZE"
MATCHOUTPUT="-o $H2MODEL -OmodelName=$MATCHEDNAME -OdbUrl=$MATCHEDDBURL -OcheckEmpty=$CHECKEMPTY"

#Changenamespace settings
CNFLAGS="$SCOREINPUT -v $VIVOCONFIG -n $NAMESPACE"

#The equality test algorithm
EQTEST="org.vivoweb.harvester.score.algorithm.EqualityTest"

#matching properties
RDFTYPE="http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
RDFSLABEL="http://www.w3.org/2000/01/rdf-schema#label"
PERSONIDNUM="http://vivoweb.org/ontology/score#personID"
ORGIDNUM="http://vivoweb.org/ontology/score#orgID"
EMAIL="http://vivoweb.org/ontology/core#email"
POSITION="http://vivoweb.org/ontology/core#positionForPerson"
BASEURI="http://vivoweb.org/harvest/csvfile/"

#clear old fetches
rm -rf $RAWRHDIR
rm -rf $RAWCSVDIR

CSVFILE="files/persontemplatetest.csv"
XSLFILE="config/datamaps/csv-people-to-vivo.xsl"

# Execute Fetch
$CSVtoJDBC -i $CSVFILE -d "org.h2.Driver" -c $RAWCSVDBURL -u "sa" -p "" -t "CSV"

FIELDS="CSV=ROWID,PERSONID,EMAIL,PHONE,FAX,FIRSTNAME,MIDNAME,LASTNAME,NAMEPREFIX,NAMESUFFIX,FULLNAME,TITLE,POSITIONTYPE,STARTDATE,ENDDATE,DEPARTMENTID,DEPARTMENTNAME"
#$JDBCFetch -d "org.h2.Driver" -c $RAWCSVDBURL -u "sa" -p "" -t "CSV" -I "CSV=ROWID" -F $FIELDS  -o $TFRH -O fileDir=$RAWRHDIR

$JDBCFetch -d "org.h2.Driver" -c $RAWCSVDBURL -u "sa" -p "" -o $TFRH -O fileDir=$RAWRHDIR

#$CSVtoRDF -o $TFRH -O fileDir=$RAWRHDIR -i $CSVFILE

# backup fetch
BACKRAW="raw"
backup-path $RAWRHDIR $BACKRAW
# uncomment to restore previous fetch
#restore-path $RAWRHDIR $BACKRAW

# clear old translates
rm -rf $RDFRHDIR

# Execute Translate
$XSLTranslator -i $TFRH -IfileDir=$RAWRHDIR -o $TFRH -OfileDir=$RDFRHDIR -x $XSLFILE
exit
# backup translate
BACKRDF="rdf"
backup-path $RDFRHDIR $BACKRDF
# uncomment to restore previous translate
#restore-path $RDFRHDIR $BACKRDF

# Clear old H2 transfer model
rm -rf $MODELDIR

# Execute Transfer to import from record handler into local temp model

$Transfer -o $H2MODEL -OmodelName=$MODELNAME -OdbUrl=$MODELDBURL -h $TFRH -HfileDir=$RDFRHDIR -n $NAMESPACE

$Transfer -i $H2MODEL -ImodelName=$MODELNAME -IdbUrl=$MODELDBURL -d $BASEDIR/transfer.rdf.xml

# backup H2 transfer Model
BACKMODEL="model"
backup-path $MODELDIR $BACKMODEL
# uncomment to restore previous H2 transfer Model
#restore-path $MODELDIR $BACKMODEL

#clear score model for next batch.
rm -rf $SCOREDATADIR

#smushes in-place(-r) on the Grant id THEN on the person ID  then deptID
$Smush $SCOREINPUT -P $PERSONIDNUM -n ${BASEURI} -r

$Transfer -i $H2MODEL -ImodelName=$MODELNAME -IdbUrl=$MODELDBURL -d $BASEDIR/smushed.rdf.xml

# Execute score to match with existing VIVO
# The -n flag value is determined by the XLST file
# The -A -W -F & -P flags need to be internally consistent per call

# Scoring of people on PERSONIDNUM
$Score $SCOREMODELS -Aufid=$EQTEST -Wufid=1.0 -Fufid=$EMAIL -Pufid=$EMAIL -n ${BASEURI}person/


$Smush $SCOREINPUT -P $ORGIDNUM -n ${BASEURI}org/ -r
# Scoring of orgs on DeptID
$Score $SCOREMODELS -AdeptID=$EQTEST -WdeptID=1.0 -FdeptID=$RDFSLABEL -PdeptID=$RDFSLABEL -n ${BASEURI}org/


$Smush $SCOREINPUT -P $RDFSLABEL -n ${BASEURI}position/ -r
# Scoring sponsors by labels
$Score $SCOREMODELS -Alabel=$EQTEST -Wlabel=1.0 -Flabel=$RDFSLABEL -Plabel=$RDFSLABEL -n ${BASEURI}position/

# Scoring of PI Roles
PIURI="-Aperson=$EQTEST -Wperson=0.5 -Fperson=$PIROLEOF -Pperson=$PIROLEOF"
GRANTURI="-Agrant=$EQTEST -Wgrant=0.5 -Fgrant=$ROLEIN -Pgrant=$ROLEIN"
$Score $SCOREMODELS $PIURI $GRANTURI -n ${BASEURI}piRole/

# Scoring of coPI Roles
COPIURI="-Aperson=$EQTEST -Wperson=0.5 -Fperson=$COPIROLEOF -Pperson=$COPIROLEOF"
$Score $SCOREMODELS $COPIURI $GRANTURI -n ${BASEURI}coPiRole/

# Find matches using scores and rename nodes to matching uri
$Match $SCOREINPUT $SCOREDATA -b $SCOREBATCHSIZE -t 1.0 -r

$Transfer -i $H2MODEL -ImodelName=$MODELNAME -IdbUrl=$MODELDBURL -d $BASEDIR/matched.rdf.xml
# Execute ChangeNamespace to get grants into current namespace
# the -o flag value is determined by the XSLT used to translate the data
$ChangeNamespace $CNFLAGS -u ${BASEURI}person/

# Execute ChangeNamespace to get orgs into current namespace
# the -o flag value is determined by the XSLT used to translate the data
$ChangeNamespace $CNFLAGS -u ${BASEURI}position/

# Execute ChangeNamespace to get sponsors into current namespace
# the -o flag value is determined by the XSLT used to translate the data
$ChangeNamespace $CNFLAGS -u ${BASEURI}org/

$Transfer -i $H2MODEL -ImodelName=$MODELNAME -IdbUrl=$MODELDBURL -d $BASEDIR/changed.rdf.xml

# backup H2 matched Model
BACKMATCHED="matched"
backup-path $MODELDIR $BACKMATCHED
# uncomment to restore previous H2 matched Model
#restore-path $MODELDIR $BACKMATCHED

# Backup pretransfer vivo database, symlink latest to latest.sql
BACKPREDB="pretransfer"
backup-mysqldb $BACKPREDB
# uncomment to restore pretransfer vivo database
#restore-mysqldb $BACKPREDB

PREVHARVESTMODEL="http://vivoweb.org/ingest/dsr"
ADDFILE="$BASEDIR/additions.rdf.xml"
SUBFILE="$BASEDIR/subtractions.rdf.xml"

# Find Subtractions
$Diff -m $H2MODEL -MdbUrl=${PREVHARVDBURLBASE}${HARVESTER_TASK}/store -McheckEmpty=$CHECKEMPTY -MmodelName=$PREVHARVESTMODEL -s $H2MODEL -ScheckEmpty=$CHECKEMPTY -SdbUrl=$MODELDBURL -SmodelName=$MODELNAME -d $SUBFILE
# Find Additions
$Diff -m $H2MODEL -McheckEmpty=$CHECKEMPTY -MdbUrl=$MODELDBURL -MmodelName=$MODELNAME -s $H2MODEL -ScheckEmpty=$CHECKEMPTY -SdbUrl=${PREVHARVDBURLBASE}${HARVESTER_TASK}/store -SmodelName=$PREVHARVESTMODEL  -d $ADDFILE

# Backup adds and subs
backup-file $ADDFILE adds.rdf.xml
backup-file $SUBFILE subs.rdf.xml
#restore-file $ADDFILE adds.rdf.xml
#restore-file $SUBFILE subs.rdf.xml

# Apply Subtractions to Previous model
$Transfer -o $H2MODEL -OdbUrl=${PREVHARVDBURLBASE}${HARVESTER_TASK}/store -OcheckEmpty=$CHECKEMPTY -OmodelName=$PREVHARVESTMODEL -r $SUBFILE -m
# Apply Additions to Previous model
$Transfer -o $H2MODEL -OdbUrl=${PREVHARVDBURLBASE}${HARVESTER_TASK}/store -OcheckEmpty=$CHECKEMPTY -OmodelName=$PREVHARVESTMODEL -r $ADDFILE
# Apply Subtractions to VIVO
$Transfer -o $VIVOCONFIG -OcheckEmpty=$CHECKEMPTY -r $SUBFILE -m
# Apply Additions to VIVO
$Transfer -o $VIVOCONFIG -OcheckEmpty=$CHECKEMPTY -r $ADDFILE

# Backup posttransfer vivo database, symlink latest to latest.sql
BACKPOSTDB="posttransfer"
backup-mysqldb $BACKPOSTDB
# uncomment to restore posttransfer vivo database
#restore-mysqldb $BACKPOSTDB

#Restart Tomcat
#Tomcat must be restarted in order for the harvested data to appear in VIVO
echo $HARVESTER_TASK ' completed successfully'

#rm cookie.txt
#rm "authenticate?loginName=defaultAdmin&loginPassword=vitro123&loginForm=1"
#wget --cookies=on --keep-session-cookies --save-cookies=cookie.txt "http://localhost:8080/vivo/authenticate?loginName=defaultAdmin&loginPassword=vitro123&loginForm=1"

#rm SearchIndex
#wget --referer=http://first_page --cookies=on --load-cookies=cookie.txt --keep-session-cookies --save-cookies=cookie.txt http://localhost:8080/vivo/SearchIndex

/etc/init.d/tomcat6 stop
/etc/init.d/apache2 restart
/etc/init.d/tomcat6 start
