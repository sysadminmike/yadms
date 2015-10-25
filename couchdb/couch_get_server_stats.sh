#!/usr/local/bin/bash

PATH=$PATH:/usr/local/bin

# Script to get info from couch to make metrics from
#
# eg: couch_get_server_stats.sh http://192.168.0.3:5984  http://192.168.0.10:5984/metrics_db staging-couch
#

couch_host=$1
metrics_host=$2
metric_prefix=$3


stats_doc=`curl -s $couch_host/_stats`
curl_exitcode=$?
if [[ $curl_exitcode -gt 0 ]]; then
	#see: http://curl.haxx.se/libcurl/c/libcurl-errors.html
	echo "Exiting: Unable to get _stats from $couch_host"
	exit $curl_exitcode
fi

if [ -z "$metric_prefix"  ]; then
        metric_prefix=`curl -s $couch_host/_config/couchdb | json uuid`        
fi

stats_doc="{ \"name\": \"$metric_prefix.couchdb\", \"type\": \"couchdb\", \"ts\": `date +%s` }$stats_doc"
stats_doc=`echo $stats_doc | json --merge`

#echo $stats_doc

#strip out description field as really not needed in every metric
stats_doc=`echo $stats_doc | json | grep -v '"description":'`
curl_out=`echo $stats_doc | curl -s -H "Accept: application/json" -H 'Content-Type: application/json' -X POST -d @- $metrics_host`

#if errror need to alert someone
echo $curl_out
