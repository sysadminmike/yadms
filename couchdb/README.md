# CouchDB Metrics

There are two scripts to pull metrics from a couchdb server and its databases - both need json npm (npm -i json)

##Metrics from couchdb server (/_stats)

```couch_get_server_stats.sh couch_host metrics_host_and_db [metric-host-name]```

This will add a single metric document basically made up of the output of /_stats with some bits cleaned up.

Example metric doc:

```
{
   "_id": "3ad893cb4cf1560add7b4caffd4b6126",
   "_rev": "1-1f0ce165e1d210319cf6e9f9c6ff654f",
   "name": "mw-staging.couchdb",
   "type": "couchdb",
   "ts": 1445785730,
   "couchdb": { 
       "auth_cache_misses": { "current": null, "sum": null, "mean":  null, "stddev": null, "min": null, "max": null },
       "database_writes":   { "current": 1955, "sum": 1955, "mean": 0.004, "stddev": 0.061, "min": 0, "max": 1 },
       "open_databases":    { "current": 47, "sum": 47, "mean": 0, "stddev": 0.03, "min": 0, "max": 14 },
       "auth_cache_hits":   { "current": null, "sum": null, "mean": null, "stddev": null, "min": null, "max": null },
       "request_time":      { "current": 934798.325, "sum": 934798.325, "mean": 247.236, "stddev": 9323.841, "min": 0, "max": 415733 },
       "database_reads":    { "current": 688315, "sum": 688315, "mean": 1.316, "stddev": 69.941, "min": 0, "max": 5497 },
       "open_os_files":     { "current": 101, "sum": 101, "mean": 0, "stddev": 0.061, "min": -1, "max": 28 }
   },
   "httpd_request_methods": {
       "PUT":    { "current": 18, "sum": 18, "mean": 0, "stddev": 0.009, "min": 0, "max": 1 },
       "GET":    { "current": 11172, "sum": 11172, "mean": 0.021, "stddev": 0.747, "min": 0, "max": 66 },
       "COPY":   { "current": null, "sum": null, "mean": null, "stddev": null, "min": null, "max": null },
       "DELETE": { "current": 2, "sum": 2, "mean": 0, "stddev": 0.003, "min": 0, "max": 1 },
       "POST":   { "current": 1948, "sum": 1948, "mean": 0.004, "stddev": 0.061, "min": 0, "max": 1 },
       "HEAD":   { "current": 1, "sum": 1, "mean": 0, "stddev": 0.004, "min": 0, "max": 1 } 
   },
   "httpd_status_codes": { 
       "200": { "current": 9073, "sum": 9073, "mean": 0.017, "stddev": 0.589, "min": 0, "max": 53 },
       "201": { "current": 1949, "sum": 1949, "mean": 0.004, "stddev": 0.061, "min": 0, "max": 1},
       "202": { "current": null, "sum": null, "mean": null, "stddev": null, "min": null, "max": null },
       "301": { "current": null, "sum": null, "mean": null, "stddev": null, "min": null, "max": null },
       "304": { "current": 81, "sum": 81, "mean": 0, "stddev": 0.026, "min": 0, "max": 3 },
       "400": { "current": 2, "sum": 2, "mean": 0, "stddev": 0.005, "min": 0, "max": 1 },
       "401": { "current": null, "sum": null, "mean": null, "stddev": null, "min": null, "max": null },
       "403": { "current": null, "sum": null, "mean": null, "stddev": null, "min": null, "max": null },
       "404": { "current": 1585, "sum": 1585, "mean": 0.007, "stddev": 0.375, "min": 0, "max": 33 },
       "405": { "current": null, "sum": null, "mean": null, "stddev": null, "min": null, "max": null },
       "409": { "current": 4, "sum": 4, "mean": 0, "stddev": 0.008, "min": 0, "max": 1 },
       "412": { "current": 2, "sum": 2, "mean": 0, "stddev": 0.006, "min": 0, "max": 1 },
       "500": { "current": 1, "sum": 1, "mean": 0, "stddev": 0.004, "min": 0, "max": 1 }
   },
   "httpd": {
       "clients_requesting_changes": { "current": 0, "sum": 0, "mean": 0, "stddev": 0.033, "min": -2, "max": 2 },
       "temporary_view_reads":       { "current": 4, "sum": 4, "mean": 0, "stddev": 0.008, "min": 0, "max": 1 },
       "requests":                   { "current": 12186, "sum": 12186, "mean": 0.023, "stddev": 0.751, "min": 0, "max": 66 },
       "bulk_requests":              { "current": 1920, "sum": 1920, "mean": 0.004, "stddev": 0.06, "min": 0, "max": 1 },
       "view_reads":                 { "current": 206, "sum": 206, "mean": 0.003, "stddev": 0.062, "min": 0, "max": 2 }
   }
}
```

Add something like below to crontab:

```*/5 * * * * /home/metrics/couch_get_server_stats.sh http://192.168.0.10:5984 http://192.168.0.100:5984/metricsdb```

TODO: Add example sql and graphs of various metrics


##Metrics on databases

```couch_get_dbs_stats.sh couch_host metrics_host_and_db [metric-host-name]```

This will add a single metric document to the couch metrcis database.

Example metric doc:

```
{
   "_id": "3ad893cb4cf1560add7b4caffd4b51e9",
   "_rev": "1-34b89ea39e72717cd707fbded169d78b",
   "name": "mw-staging.couchdb_dbs",
   "type": "couchdb_dbs",
   "ts": 1445785379,
   "dbs": [
       {
           "db_name": "_replicator",
           "doc_count": 1,
           "doc_del_count": 4,
           "update_seq": 20,
           "purge_seq": 0,
           "compact_running": false,
           "disk_size": 61544,
           "data_size": 7180,
           "instance_start_time": "1445258439000337",
           "disk_format_version": 6,
           "committed_update_seq": 20
       },
       {
           "db_name": "_users",
           "doc_count": 1,
           "doc_del_count": 0,
           "update_seq": 1,
           "purge_seq": 0,
           "compact_running": false,
           "disk_size": 8290,
           "data_size": 4909,
           "instance_start_time": "1445258438942010",
           "disk_format_version": 6,
           "committed_update_seq": 1
       },
       {
           "db_name": "aatest",
           "doc_count": 2326396,
           "doc_del_count": 0,
           "update_seq": 2326400,
           "purge_seq": 0,
           "compact_running": false,
           "disk_size": 641687665,
           "data_size": 575344231,
           "instance_start_time": "1445258443050873",
           "disk_format_version": 6,
           "committed_update_seq": 2326400
       },
       {
           "db_name": "abtest",
           "doc_count": 331,
           "doc_del_count": 4,
           "update_seq": 343,
           "purge_seq": 0,
           "compact_running": false,
           "disk_size": 278641,
           "data_size": 123179,
           "instance_start_time": "1445545165301518",
           "disk_format_version": 6,
           "committed_update_seq": 343
       }
   ]
}
```

Add something like below to crontab:

```0 0,6,12,18 * * * /home/metrics/couch_get_dbs_stats.sh http://192.168.0.10:5984 http://192.168.0.100:5984/metricsdb```

Adjust frequency of collection as required.


TODO: Add example sql and graphs of various metrics