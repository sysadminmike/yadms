#!/usr/local/bin/bash

# Script to get info from couch to make metrics from
#
# eg: couch_get_dbs_stats.sh couch_host metrics_host_and_db [metric-host-name]
#     
#     if metric-host-name not specified script will use couchdb.uuid from couch_host/_config
#
#     if doc_type_count_view var is set then script will then try to get stats on docs
#     by checking if view /_design/system_admin/_view/count_doc_types exists in the db
#     this can be easily extended for counts based on other views as needed
#
# example design doc to add to db:
# {
#    "_id": "_design/system_admin",
#    "views": {
#        "count_doc_types": {
#           "map": "function(doc) { if (!doc['type']) { emit('null', 1);  }else{ emit(doc.type, 1); }   }",
#           "reduce": "function (key, values, rereduce) { return sum(values); }"
#        }
#    }
# }
#

couch_host=$1
metrics_host=$2
metric_prefix=$3

#doc_type_count_view="_design/system_admin/_view/count_doc_types?&group=true" #comment out if not wanted

all_dbs=`curl -s $couch_host/_all_dbs`
curl_exitcode=$?
if [[ $curl_exitcode -gt 0 ]]; then
	#see: http://curl.haxx.se/libcurl/c/libcurl-errors.html
	echo "Exiting: Unable to get db list from $couch_host"
	exit $curl_exitcode
fi
all_dbs=`echo $all_dbs | json -ga  | sort`

if [ -z "$metric_prefix"  ]; then
	metric_prefix=`curl -s $couch_host/_config/couchdb | json uuid`
fi

for db in $all_dbs; do
        db_doc=`curl -s $couch_host/$db`

        if [ ! -z "${doc_type_count_view}" ]; then
            doc_type_count=`curl -s "$couch_host/$db/$doc_type_count_view"`
            if [ "$doc_type_count" != '{"error":"not_found","reason":"missing"}' ]; then   #view exists
                 doc_type_count=`echo $doc_type_count | sed 's/"rows":/"doc_types_count":/g' | sed 's/"key"://g' | sed 's/,"value"//g'`
                 db_doc=`echo $db_doc\$doc_type_count | json --merge`
             fi
        fi
        dbs_doc="$dbs_doc$db_doc,"
done
dbs_doc=${dbs_doc::-1}  #kill last comma

dbs_doc="{\"dbs\":[$dbs_doc]}"

final_doc="{ \"name\": \"$metric_prefix.couchdb_dbs\", \"type\": \"couchdb_dbs\", \"ts\": `date +%s` }$dbs_doc"

final_doc=`echo $final_doc\$dbs_doc | json --merge | tr -d '\n'`

#send to metric_host
curl_out=`echo $final_doc | curl -s -H "Accept: application/json" -H 'Content-Type: application/json' -X POST -d @- $metrics_host`

#test above sucseeded - if not send metric as email 
echo $curl_out
