# CouchDB Metrics

There are two scripts to pull metrics from a couchdb server and its databases - both need json npm (npm -i json)

![Example couch dashboard](/couchdb/pics/couch.png)

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



### Open Databases & Open OS Files

```
WITH couchdb_current AS (
	SELECT (doc->>'ts')::numeric * 1000 AS time,
	(doc->'couchdb'->'open_databases'->>'current')::numeric AS open_databases,
	(doc->'couchdb'->'open_os_files'->>'current')::numeric AS open_os_files
	FROM abtest
	WHERE doc->>'name'='mw-staging.couchdb' 
	AND ( to_timestamp((doc->>'ts')::numeric) > now() - interval '12h')
),

results AS (    
  SELECT '{ "results": [' AS v     
  UNION ALL
  SELECT '{ "series": [{ "name": "mw-staging.couchdb.open_databases", "columns": ["time", "value"], "values": ' || json_agg(json_build_array(time,open_databases))  || ' }] }'
    AS v FROM couchdb_current 
  UNION ALL
  SELECT ',{ "series": [{ "name": "mw-staging.couchdb.open_os_files", "columns": ["time", "value"], "values": ' || json_agg(json_build_array(time,open_os_files))  || ' }] }'
    AS v FROM couchdb_current 
  UNION ALL
  SELECT ']}' AS v   
)
SELECT string_agg(v,'') AS ret FROM results
```

![Example couch open dbs and files](/couchdb/pics/couch-open-dbs-files.png)


### Reads / Writes per sec + average time per request (ms)

```
WITH couch_read_writes AS (
  SELECT (doc->>'ts')::numeric * 1000 AS  time,
         ((doc->'couchdb'->'database_reads'->>'current')::numeric - lag((doc->'couchdb'->'database_reads'->>'current')::numeric, 1, '0') OVER w )
           / ((doc->>'ts')::numeric - lag((doc->>'ts')::numeric, 1, '1') OVER w)::numeric AS  database_reads_per_sec,
         ((doc->'couchdb'->'database_writes'->>'current')::numeric - lag((doc->'couchdb'->'database_writes'->>'current')::numeric, 1, '0') OVER w )
           / ((doc->>'ts')::numeric - lag((doc->>'ts')::numeric, 1, '1') OVER w)::numeric AS  database_writes_per_sec,
         ((doc->'couchdb'->'request_time'->>'current')::numeric - lag((doc->'couchdb'->'request_time'->>'current')::numeric, 1, '0') OVER w )
         / ((doc->'httpd'->'requests'->>'current')::numeric - lag((doc->'httpd'->'requests'->>'current')::numeric, 1, '1') OVER w)::numeric AS  request_time_per_request
    FROM abtest
    WHERE doc->>'name'='mw-staging.couchdb' 
      WINDOW w AS  (ORDER BY (doc->>'ts')::numeric)   
    ORDER BY time
),
results AS (    
  SELECT '{ "results": [' AS v     
  UNION ALL
   SELECT '{ "series": [{ "name": "database_reads_per_sec", "columns": ["time", "value"], "values": ' || json_agg(json_build_array(time,ROUND(database_reads_per_sec,2)))  || ' }] }'
    AS v FROM couch_read_writes 
  UNION ALL 
   SELECT ',{ "series": [{ "name": "database_writes_per_sec", "columns": ["time", "value"], "values": ' || json_agg(json_build_array(time,ROUND(database_writes_per_sec,2)))  || ' }] }'
    AS v FROM couch_read_writes 
  UNION ALL 
   SELECT ',{ "series": [{ "name": "avg_request_time_ms_per_request", "columns": ["time", "value"], "values": ' || json_agg(json_build_array(time,ROUND(request_time_per_request*1000,2)))  || ' }] }'
    AS v FROM couch_read_writes 

  UNION ALL
  SELECT ']}' AS v   
 )
 SELECT string_agg(v,'') AS ret FROM results
```

Note on the ```avg_request_time_ms_per_request``` shows how flexible this can be as you can access other metrics collected to work this out - ie doc->'httpd'->'requests'->>'current' 

![Example couch read/writes per min](/couchdb/pics/couch-read-write2.png)


### Http status codes & methods per sec

```
WITH httpd_metrics AS (
  SELECT (doc->>'ts')::numeric * 1000 AS  time,

         ((doc->'httpd_status_codes'->'200'->>'current')::numeric - lag((doc->'httpd_status_codes'->'200'->>'current')::numeric, 1, '0') OVER w )
           / ((doc->>'ts')::numeric - lag((doc->>'ts')::numeric, 1, '1') OVER w)::numeric AS  code_200_per_sec,
         ((doc->'httpd_status_codes'->'201'->>'current')::numeric - lag((doc->'httpd_status_codes'->'201'->>'current')::numeric, 1, '0') OVER w )
            / ((doc->>'ts')::numeric - lag((doc->>'ts')::numeric, 1, '1') OVER w)::numeric AS  code_201_per_sec,
         ((doc->'httpd_status_codes'->'202'->>'current')::numeric - lag((doc->'httpd_status_codes'->'202'->>'current')::numeric, 1, '0') OVER w )
            / ((doc->>'ts')::numeric - lag((doc->>'ts')::numeric, 1, '1') OVER w)::numeric AS  code_202_per_sec,

         ((doc->'httpd_status_codes'->'301'->>'current')::numeric - lag((doc->'httpd_status_codes'->'301'->>'current')::numeric, 1, '0') OVER w )
            / ((doc->>'ts')::numeric - lag((doc->>'ts')::numeric, 1, '1') OVER w)::numeric AS  code_301_per_sec,
         ((doc->'httpd_status_codes'->'304'->>'current')::numeric - lag((doc->'httpd_status_codes'->'304'->>'current')::numeric, 1, '0') OVER w )
            / ((doc->>'ts')::numeric - lag((doc->>'ts')::numeric, 1, '1') OVER w)::numeric AS  code_304_per_sec,

         ((doc->'httpd_status_codes'->'400'->>'current')::numeric - lag((doc->'httpd_status_codes'->'400'->>'current')::numeric, 1, '0') OVER w )
           / ((doc->>'ts')::numeric - lag((doc->>'ts')::numeric, 1, '1') OVER w)::numeric AS  code_400_per_sec,
         ((doc->'httpd_status_codes'->'401'->>'current')::numeric - lag((doc->'httpd_status_codes'->'401'->>'current')::numeric, 1, '0') OVER w )
            / ((doc->>'ts')::numeric - lag((doc->>'ts')::numeric, 1, '1') OVER w)::numeric AS  code_401_per_sec,
         ((doc->'httpd_status_codes'->'403'->>'current')::numeric - lag((doc->'httpd_status_codes'->'403'->>'current')::numeric, 1, '0') OVER w )
            / ((doc->>'ts')::numeric - lag((doc->>'ts')::numeric, 1, '1') OVER w)::numeric AS  code_403_per_sec,
         ((doc->'httpd_status_codes'->'404'->>'current')::numeric - lag((doc->'httpd_status_codes'->'404'->>'current')::numeric, 1, '0') OVER w )
            / ((doc->>'ts')::numeric - lag((doc->>'ts')::numeric, 1, '1') OVER w)::numeric AS  code_404_per_sec,
         ((doc->'httpd_status_codes'->'409'->>'current')::numeric - lag((doc->'httpd_status_codes'->'409'->>'current')::numeric, 1, '0') OVER w )
            / ((doc->>'ts')::numeric - lag((doc->>'ts')::numeric, 1, '1') OVER w)::numeric AS  code_409_per_sec,
         ((doc->'httpd_status_codes'->'412'->>'current')::numeric - lag((doc->'httpd_status_codes'->'412'->>'current')::numeric, 1, '0') OVER w )
            / ((doc->>'ts')::numeric - lag((doc->>'ts')::numeric, 1, '1') OVER w)::numeric AS  code_412_per_sec,

         ((doc->'httpd_status_codes'->'500'->>'current')::numeric - lag((doc->'httpd_status_codes'->'500'->>'current')::numeric, 1, '0') OVER w )
            / ((doc->>'ts')::numeric - lag((doc->>'ts')::numeric, 1, '1') OVER w)::numeric AS  code_500_per_sec,

         ((doc->'httpd_request_methods'->'PUT'->>'current')::numeric - lag((doc->'httpd_request_methods'->'PUT'->>'current')::numeric, 1, '0') OVER w )
            / ((doc->>'ts')::numeric - lag((doc->>'ts')::numeric, 1, '1') OVER w)::numeric AS  put_per_sec,
         ((doc->'httpd_request_methods'->'GET'->>'current')::numeric - lag((doc->'httpd_request_methods'->'GET'->>'current')::numeric, 1, '0') OVER w )
            / ((doc->>'ts')::numeric - lag((doc->>'ts')::numeric, 1, '1') OVER w)::numeric AS  get_per_sec,
         ((doc->'httpd_request_methods'->'POST'->>'current')::numeric - lag((doc->'httpd_request_methods'->'POST'->>'current')::numeric, 1, '0') OVER w )
            / ((doc->>'ts')::numeric - lag((doc->>'ts')::numeric, 1, '1') OVER w)::numeric AS  post_per_sec,
         ((doc->'httpd_request_methods'->'DELETE'->>'current')::numeric - lag((doc->'httpd_request_methods'->'DELETE'->>'current')::numeric, 1, '0') OVER w )
            / ((doc->>'ts')::numeric - lag((doc->>'ts')::numeric, 1, '1') OVER w)::numeric AS  delete_per_sec,
         ((doc->'httpd_request_methods'->'HEAD'->>'current')::numeric - lag((doc->'httpd_request_methods'->'HEAD'->>'current')::numeric, 1, '0') OVER w )
            / ((doc->>'ts')::numeric - lag((doc->>'ts')::numeric, 1, '1') OVER w)::numeric AS  head_per_sec,
         ((doc->'httpd_request_methods'->'COPY'->>'current')::numeric - lag((doc->'httpd_request_methods'->'COPY'->>'current')::numeric, 1, '0') OVER w )
            / ((doc->>'ts')::numeric - lag((doc->>'ts')::numeric, 1, '1') OVER w)::numeric AS  copy_per_sec


    FROM abtest
    WHERE doc->>'name'='mw-staging.couchdb' 
      WINDOW w AS  (ORDER BY (doc->>'ts')::numeric)   
    ORDER BY time
),
results AS (    
  SELECT '{ "results": [' AS v     
  UNION ALL

  SELECT '{ "series": [{ "name": "200", "columns": ["time", "value"], "values": ' || json_agg(json_build_array(time,ROUND(code_200_per_sec,2)))  || ' }] }'
    AS v FROM httpd_metrics 
  UNION ALL
  SELECT ',{ "series": [{ "name": "201", "columns": ["time", "value"], "values": ' || json_agg(json_build_array(time,ROUND(code_201_per_sec,2)))  || ' }] }'
    AS v FROM httpd_metrics 
  UNION ALL
  SELECT ',{ "series": [{ "name": "202", "columns": ["time", "value"], "values": ' || json_agg(json_build_array(time,ROUND(code_202_per_sec,2)))  || ' }] }'
    AS v FROM httpd_metrics 
  UNION ALL

  SELECT ',{ "series": [{ "name": "301", "columns": ["time", "value"], "values": ' || json_agg(json_build_array(time,ROUND(code_301_per_sec,2)))  || ' }] }'
    AS v FROM httpd_metrics 
  UNION ALL
  SELECT ',{ "series": [{ "name": "304", "columns": ["time", "value"], "values": ' || json_agg(json_build_array(time,ROUND(code_304_per_sec,2)))  || ' }] }'
    AS v FROM httpd_metrics 
  UNION ALL

  SELECT ',{ "series": [{ "name": "400", "columns": ["time", "value"], "values": ' || json_agg(json_build_array(time,ROUND(code_400_per_sec,2)))  || ' }] }'
    AS v FROM httpd_metrics 
  UNION ALL
  SELECT ',{ "series": [{ "name": "401", "columns": ["time", "value"], "values": ' || json_agg(json_build_array(time,ROUND(code_401_per_sec,2)))  || ' }] }'
    AS v FROM httpd_metrics 
  UNION ALL
  SELECT ',{ "series": [{ "name": "403", "columns": ["time", "value"], "values": ' || json_agg(json_build_array(time,ROUND(code_403_per_sec,2)))  || ' }] }'
    AS v FROM httpd_metrics 
  UNION ALL
  SELECT ',{ "series": [{ "name": "404", "columns": ["time", "value"], "values": ' || json_agg(json_build_array(time,ROUND(code_404_per_sec,2)))  || ' }] }'
    AS v FROM httpd_metrics 
  UNION ALL
  SELECT ',{ "series": [{ "name": "409", "columns": ["time", "value"], "values": ' || json_agg(json_build_array(time,ROUND(code_409_per_sec,2)))  || ' }] }'
    AS v FROM httpd_metrics 
  UNION ALL
  SELECT ',{ "series": [{ "name": "412", "columns": ["time", "value"], "values": ' || json_agg(json_build_array(time,ROUND(code_412_per_sec,2)))  || ' }] }'
    AS v FROM httpd_metrics 
  UNION ALL

  SELECT ',{ "series": [{ "name": "500", "columns": ["time", "value"], "values": ' || json_agg(json_build_array(time,ROUND(code_500_per_sec,2)))  || ' }] }'
    AS v FROM httpd_metrics 
  UNION ALL


  SELECT ',{ "series": [{ "name": "GET", "columns": ["time", "value"], "values": ' || json_agg(json_build_array(time,ROUND(get_per_sec,2)))  || ' }] }'
    AS v FROM httpd_metrics 
  UNION ALL
  SELECT ',{ "series": [{ "name": "PUT", "columns": ["time", "value"], "values": ' || json_agg(json_build_array(time,ROUND(put_per_sec,2)))  || ' }] }'
    AS v FROM httpd_metrics 
  UNION ALL
  SELECT ',{ "series": [{ "name": "POST", "columns": ["time", "value"], "values": ' || json_agg(json_build_array(time,ROUND(post_per_sec,2)))  || ' }] }'
    AS v FROM httpd_metrics 
  UNION ALL
  SELECT ',{ "series": [{ "name": "DELETE", "columns": ["time", "value"], "values": ' || json_agg(json_build_array(time,ROUND(delete_per_sec,2)))  || ' }] }'
    AS v FROM httpd_metrics 
  UNION ALL
  SELECT ',{ "series": [{ "name": "HEAD", "columns": ["time", "value"], "values": ' || json_agg(json_build_array(time,ROUND(head_per_sec,2)))  || ' }] }'
    AS v FROM httpd_metrics 
  UNION ALL
  SELECT ',{ "series": [{ "name": "COPY", "columns": ["time", "value"], "values": ' || json_agg(json_build_array(time,ROUND(copy_per_sec,2)))  || ' }] }'
    AS v FROM httpd_metrics 
  UNION ALL

  SELECT ']}' AS v   
)
SELECT string_agg(v,'') AS ret FROM results) AS ret FROM results
```

![Example couch status codes per min](/couchdb/pics/couch-httpd2.png)

![Example couch status codes per min](/couchdb/pics/couch-http-status-codes.png) 
Note: Ledgend min, max, avg, current and total are from grafana and not the couch stats doc.


### httpd info per sec

```
WITH httpd AS (
    SELECT (doc->>'ts')::numeric * 1000 AS  time, id,
         (doc->'httpd'->'clients_requesting_changes'->>'current')::numeric AS clients_requesting_changes,
         ((doc->'httpd'->'requests'->>'current')::numeric - lag((doc->'httpd'->'requests'->>'current')::numeric, 1, '0') OVER w )
           / ((doc->>'ts')::numeric - lag((doc->>'ts')::numeric, 1, '1') OVER w)::numeric AS requests_per_sec,
         ((doc->'httpd'->'bulk_requests'->>'current')::numeric - lag((doc->'httpd'->'bulk_requests'->>'current')::numeric, 1, '0') OVER w )
           / ((doc->>'ts')::numeric - lag((doc->>'ts')::numeric, 1, '1') OVER w)::numeric AS bulk_requests_per_sec,
         ((doc->'httpd'->'view_reads'->>'current')::numeric - lag((doc->'httpd'->'view_reads'->>'current')::numeric, 1, '0') OVER w )
           / ((doc->>'ts')::numeric - lag((doc->>'ts')::numeric, 1, '1') OVER w)::numeric AS view_reads_per_sec,
         ((doc->'httpd'->'temporary_view_reads'->>'current')::numeric - lag((doc->'httpd'->'temporary_view_reads'->>'current')::numeric, 1, '0') OVER w )
           / ((doc->>'ts')::numeric - lag((doc->>'ts')::numeric, 1, '1') OVER w)::numeric AS temporary_view_reads_per_sec
    FROM abtest
    WHERE doc->>'name'='mw-staging.couchdb' 
    WINDOW w AS  (ORDER BY (doc->>'ts')::numeric)    
    ORDER BY time
),         
results AS (    
  SELECT '{ "results": [' AS v     
  UNION ALL           
  SELECT '{ "series": [{ "name": "clients_requesting_changes", "columns": ["time", "value"], "values": ' || json_agg(json_build_array(time,clients_requesting_changes))  || ' }] }'
    AS v FROM httpd 
  UNION ALL
  SELECT ',{ "series": [{ "name": "requests", "columns": ["time", "value"], "values": ' || json_agg(json_build_array(time,ROUND(requests_per_sec,2)*60))  || ' }] }'
    AS v FROM httpd
  UNION ALL
  SELECT ',{ "series": [{ "name": "bulk_requests", "columns": ["time", "value"], "values": ' || json_agg(json_build_array(time,ROUND(bulk_requests_per_sec,2)*60))  || ' }] }'
    AS v FROM httpd
  UNION ALL
  SELECT ',{ "series": [{ "name": "view_reads", "columns": ["time", "value"], "values": ' || json_agg(json_build_array(time,ROUND(view_reads_per_sec,2)*60))  || ' }] }'
    AS v FROM httpd
  UNION ALL
  SELECT ',{ "series": [{ "name": "temporary_view_reads", "columns": ["time", "value"], "values": ' || json_agg(json_build_array(time,ROUND(temporary_view_reads_per_sec,2)*60))  || ' }] }'
    AS v FROM httpd
  UNION ALL
  SELECT ']}' AS v   
)
SELECT string_agg(v,'') AS ret FROM results
```

![Example couch httpd per min](/couchdb/pics/couch-httpd.png)


![Example couch httpd per min](/couchdb/pics/couch-httpd-and-codes.png)



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



### database doc types count 

When the doc.type map/reduce is in place and the couch_get_dbs_stats.sh has it enabled a metric doc looks something like the below:

```
{
   "_id": "3ad893cb4cf1560add7b4caffd4adfac",
   "_rev": "1-41d8695a6d2d0a4dec24e9f90e67c967",
   "name": "myname.couch_dbs_stats",
   "type": "couch_dbs_stats",
   "ts": 1445725502,
   "dbs": [
       {
           "db_name": "aatest",
           "doc_count": 2326396,
           "doc_del_count": 0,
           "update_seq": 2326398,
           "purge_seq": 0,
           "compact_running": false,
           "disk_size": 641671281,
           "data_size": 575344173,
           "instance_start_time": "1445258443050873",
           "disk_format_version": 6,
           "committed_update_seq": 2326398,
           "doc_types_count": [
               {
                   "counter": 594423
               },
               {
                   "counter_rate": 51942
               },
               {
                   "cpu": 9813
               },
               {
                   "gauges": 542081
               },
               {
                   "if": 9809
               },
               {
                   "io": 14706
               },
               {
                   "load": 9809
               },
               {
                   "mem": 9809
               },
               {
                   "null": 2
               },
               {
                   "set": 542000
               },
               {
                   "timers": 542000
               }
           ]
       },
       {
           "db_name": "abtest",
           "doc_count": 315,
           "doc_del_count": 4,
           "update_seq": 326,
           "purge_seq": 0,
           "compact_running": false,
           "disk_size": 163953,
           "data_size": 75808,
           "instance_start_time": "1445545165301518",
           "disk_format_version": 6,
           "committed_update_seq": 326,
           "doc_types_count": [
               {
                   "counter": 311
               },
               {
                   "gauge": 2
               },
               {
                   "timers": 1
               }
           ]
       }
   ]
}
```

Below will return all of the doc types count series for a metric and couch db name:
```

CREATE OR REPLACE VIEW couch_dbs_stats AS 
 WITH dbs AS (
         SELECT abtest.doc ->> 'ts'::text AS "time",
            abtest.doc ->> 'name'::text AS metric_name,
            json_array_elements((abtest.doc ->> 'dbs'::text)::json) AS adoc
           FROM abtest
          WHERE (abtest.doc ->> 'type'::text) = 'couch_dbs_stats'::text
        ), doc_types_counts_working AS (
         SELECT dbs."time",
            dbs.metric_name,
            dbs.adoc ->> 'db_name'::text AS db_name,
            json_array_elements((dbs.adoc ->> 'doc_types_count'::text)::json) AS mdoc
           FROM dbs
          WHERE (dbs.adoc ->> 'doc_types_count'::text) IS NOT NULL
        )
 SELECT doc_types_counts_working."time",
    doc_types_counts_working.metric_name,
    doc_types_counts_working.db_name,
    json_object_keys(doc_types_counts_working.mdoc) AS doc_type,
    doc_types_counts_working.mdoc ->> json_object_keys(doc_types_counts_working.mdoc) AS doc_count
   FROM doc_types_counts_working;
```

```
CREATE OR REPLACE FUNCTION get_couch_dbs_doc_type_counts(metricname TEXT, dbname TEXT)
  RETURNS text AS
$BODY$
DECLARE  
  doctype text;
  rec record;
  sql TEXT := '';
  result TEXT;
BEGIN
  FOR doctype IN   
      SELECT DISTINCT doc_type AS doctype FROM couch_dbs_stats WHERE metric_name=metricname AND db_name=dbname
  LOOP
    sql := sql || 'SELECT '',{ "series": [{ "name": "' || dbname || '.' || doctype || '", "columns": ["time", "count"], "values": '' || json_agg(json_build_array((time::numeric * 1000),doc_count::numeric))  || '' }] }'' AS v FROM couch_dbs_stats UNION ALL ';
  END LOOP;
  sql := 'SELECT ''' || left( right(sql,length(sql)-9), -10 ) ;

  result := '';
  FOR rec IN EXECUTE sql LOOP
	result := result || rec.v;
  END LOOP;
  RETURN result;

END
$BODY$
  LANGUAGE plpgsql;
```
To be called from grafana as:
```
SELECT '{ "results": [' || get_couch_dbs_doc_type_counts('myname.couch_dbs_stats','aatest') || ']}' AS ret
```
