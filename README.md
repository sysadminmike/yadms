# yadms
Yet another distributed metrics setup

![Example Setup](/pics/example-setup.png)

![Example Graph 1](/pics/example-1.png)

There is no loss of resolution like with rrd files or time series databases as time passes - its up to however you need to manage your metrics to aggregate/roll them up as required but with TB hard disks so cheap for small setups keeping all metrics is more than possible.

Allows for flexible collection of metrics with no strict schema making it very simple to add extra datasources.

Below is an example using symon/symux to collect metrics.

[Couchdb metrics](./couchdb/README.md)

## Setup of host(s) sending metrics

Install symon without symux:

FreeBSD 

```portmaster -mWITHOUT_SYMUX=yes sysutils/symon```

Add ```symon_enable="YES"``` to ```/etc/rc.conf```

Config location: ```/usr/local/etc/symon.conf```


OpenBSD 

```pkg_add symon-mon-version.tgz``` config location: ```/etc/symon.conf```


Linux - http://wpd.home.xs4all.nl/symon/documentation.html

Windows - https://github.com/ValHazelwood/SymonClient


Edit ```symon.conf``` as needed eg:

```
monitor { cpu, mem, load,
          if(re0),
          io(ada0), io(ada1), io(ada2)
} every 30 seconds stream to 192.168.0.10 2100

monitor { df(home) } every 300 seconds stream to 192.168.0.10 2100
```

192.168.0.10 is the host running symux.

See http://wpd.home.xs4all.nl/symon/documentation.html for more info on symon and setup.



## Setup of metrics collection host at each separated datacenter/location.  

In this example its assumed couchdb is installed on this machine but it is possible to run these services however is required and they dont have to be on the same machine or even in the same network but if connectivity is lost between the bits then metrics will be lost.


### symux 
http://wpd.home.xs4all.nl/symon/documentation.html

Install symux and edit ``symux.conf``` as needed.

For example to collect from the above symon example:

```
mux 192.168.3.22 2100

source 192.168.0.2 {
        accept { cpu, mem, load,
                 if(re0),
                 io(ada0), io(ada1), io(ada2), df(home)
        }
}
source 192.168.0.3 {
        accept { cpu, mem, load, if(bge0), io(ada0) }
}
```

Note: Ther is no need for any write options like: ```write if(sis1) in "/var/www/symon/rrds/4512/if_sis1.rrd"``` - symux will output a warning when starting which can be ignored.

Test all is ok by telneting to it and check you can see packets from the symon hosts coming to symux host:

```
$ telnet 192.168.0.10 2100
Trying 192.168.0.10...
Connected to 192.168.0.10.
Escape character is '^]'.
192.168.0.2;io:ada2:1445185079:331661989:33510675:0:1841248609280:207472103936;io:ada1:1445185079:64168907:184701854:0:382896989184:2969114132992;io:ada0:1445185079:64267879:185018998:0:381249819648:2969114132992;if:re0:1445185079:285018715:260987307:217618087580:127074969929:600951:0:0:0:0:0;load::1445185079:1.68:1.21:0.69;mem::1445185079:981999616:3464994816:767479808:133165056:10737414144;cpu::1445185079:10.40:0.00:1.50:0.40:87.70;
```


### symux-to-couch
https://github.com/sysadminmike/symux-to-couch

Install ```npm i symux-to-couch``` and edit as required (couchdb and symux info) also add each host and name to this as symux outputs ip and not hostname.

Run it ```node symux-to-couch.js``` and you should start to see documents being added to couchdb.


### statsd

If needed statsd with https://github.com/sysadminmike/couch-statsd-backend this will allow statsd clients in this datacenter/location to send stats to couch and be sent to central location along with symon and other metrics.  For example from collectd when https://github.com/collectd/collectd/pull/1296 is merged it will be possible to use collectd metrics as well.


### Other
Possibly turn this host into a log server for the datacenter/location and add fluentd to ship logs to couch.






## Setup of host(s) to view/anaylise/graph metrics 

Assumes couchdb, postgres, grafana all ready.


### couchdb replication 

In order to collect all of the couchdb docs to a central location the following design doc is required in each 'metric' database per datacenter/location/satelite couchdb, this allows for the periodic clearing up of these couchdbs without affecting the 'all_metrics' database. 

Note you could install postgres at a location and not replicate all locations to a single couchdb or if only one location then no need to separate couch and postgres and skip this bit.

```
{
   "_id": "_design/system_admin",
   "filters": { "NoDelete": "function(doc, req) { if (!doc._deleted) { return true; } else { return false; } }" }
}
```

Doc to add to _replicator on all_metrics couchdb host (need one per datacenter/location/satelite couchdb):
```
{
   "_id": "location1-metrics-to-all_metrics",
   "source": "http://192.168.0.10:5984/metrics",
   "target": "all_metrics",
   "filter": "system_admin/NoDelete",
   "continuous": true,
   "user_ctx": { "roles": ["_admin"] },
   "owner": null
}
```

Note: Instead of using a single all_metrics database you can use a database per location.
Also need to test delete stuff and make sure it works for delete when not done via bulk deletes?

### couch-to-postgres
https://github.com/sysadminmike/couch-to-postgres

```
npm i couch-to-postgres
```

Edit config as required and start.


Note in postgres we need a table per couchdb database:
```
CREATE TABLE all_metrics
(
  id text NOT NULL,
  doc jsonb,
  CONSTRAINT all_metrics_pkey PRIMARY KEY (id)
);
```

Also to speed things up significantly lets add an index (more can be added):

```
CREATE INDEX all_metrics_name
  ON all_metrics
  USING btree
  ((doc #>> '{name}'::text[]) COLLATE pg_catalog."default");
```

You should see the couchdb docs appearing in postgres.

### couch-to-influx
https://github.com/sysadminmike/couch-to-influx
Instead of postgres you could pump the data into influxdb - note this needs work and was initially for statsd metrics so may need some work for symux metrics and do not think this can be used for logs and other odd metric data postgres will be able to handle.  Personally I didnt get on with influxdb on freebsd so am not using it.

## Grafana 

In order to get the data into grafana we need postgres to pretend to be influxdb.

###postgres-influx-mimic

```npm i postgres-influx-mimic```

Edit as and change as requried see https://github.com/sysadminmike/postgres-influx-mimic for more info.

Add this as an influxdb datasource to grafana.

![Grafana Datasource Setup](/pics/grafana-datasource-setup.png)



## Example of graphing symux resources from postgres:

### load

example doc:
```
{
   "_id": "344306990d4f3590bb779b66d367c2a4",
   "_rev": "1-d210dcd5ce8b5f4c530b3a470c552bc4",
   "name": "mw-f10.load",
   "type": "load",
   "ts": 1445110010,
   "load1": 0.31,
   "load5": 0.4,
   "load15": 0.4
}
```

example sql:
```
WITH  
results1 AS (
   SELECT (doc->>'ts')::numeric * 1000 AS time, (doc->>'load1')::numeric AS value FROM all_metrics
   WHERE doc #>> '{name}'='mw-f10.load' 
   AND ( to_timestamp((doc->>'ts')::numeric) > now() - interval '6h')
   ORDER BY time
),
results2 AS (
   SELECT (doc->>'ts')::numeric * 1000 AS time, (doc->>'load5')::numeric AS value FROM all_metrics 
   WHERE doc #>> '{name}'='mw-f10.load' 
   AND ( to_timestamp((doc->>'ts')::numeric) > now() - interval '6h')
   ORDER BY time
),
results3 AS (
   SELECT (doc->>'ts')::numeric * 1000 AS time, (doc->>'load15')::numeric AS value FROM all_metrics 
   WHERE doc #>> '{name}'='mw-f10.load' 
   AND ( to_timestamp((doc->>'ts')::numeric) > now() - interval '6h')
   ORDER BY time
),

results AS (    
  SELECT '{ "results": [' AS v     
  UNION ALL
    SELECT '{ "series": [{ "name": "mw-f10.load1", "columns": ["time", "value"], "values": ' || json_agg(json_build_array(time,value))  || ' }] }'
    AS v FROM results1     
  UNION ALL
    SELECT ',{ "series": [{ "name": "mw-f10.load5", "columns": ["time", "value"], "values": ' || json_agg(json_build_array(time,value))  || ' }] }'
    AS v FROM results2     
  UNION ALL
    SELECT ',{ "series": [{ "name": "mw-f10.load15", "columns": ["time", "value"], "values": ' || json_agg(json_build_array(time,value))  || ' }] }'
    AS v FROM results3    
  UNION ALL
  SELECT ']}' AS v 
) 
SELECT string_agg(v,'') AS ret FROM results
```

![Example load graph 1](/pics/metrics-load-1.png)
![Example load graph 2](/pics/metrics-load-2.png)


### cpu

```
{
   "_id": "3174aa1f4c88f1eb9df4750ca70098ec",
   "_rev": "1-e81087bf24a7ef9a925dfdcb01e624d8",
   "name": "mw-f10.cpu",
   "type": "cpu",
   "ts": 1445190779,
   "user": 10.19,
   "nice": 0,
   "system": 1.6,
   "interrupt": 0.6,
   "idle": 87.5
}
```

```
WITH   
results1 AS (
   SELECT (doc->>'ts')::numeric * 1000 AS time, (doc->>'user')::numeric as value FROM all_metrics  
   WHERE doc #>> '{name}'='mw-f10.cpu' 
   AND ( to_timestamp((doc->>'ts')::numeric) > now() - interval '24h')
   ORDER BY time
),   
results2 AS (
   SELECT (doc->>'ts')::numeric * 1000 AS time, (doc->>'nice')::numeric as value FROM all_metrics  
   WHERE doc #>> '{name}'='mw-f10.cpu' 
   AND ( to_timestamp((doc->>'ts')::numeric) > now() - interval '24h')
   ORDER BY time
),  
results3 AS (
   SELECT (doc->>'ts')::numeric * 1000 AS time, (doc->>'system')::numeric as value FROM all_metrics 
   WHERE doc #>> '{name}'='mw-f10.cpu' 
   AND ( to_timestamp((doc->>'ts')::numeric) > now() - interval '24h')
   ORDER BY time
), 
results4 AS (
   SELECT (doc->>'ts')::numeric * 1000 AS time, (doc->>'interrupt')::numeric as value FROM all_metrics  
   WHERE doc #>> '{name}'='mw-f10.cpu' 
   AND ( to_timestamp((doc->>'ts')::numeric) > now() - interval '24h')
   ORDER BY time
), 

results AS (    
 SELECT '{ "results": [' AS v     
 UNION ALL
   SELECT '{ "series": [{ "name": "mw-f10.cpu.user", "columns": ["time", "value"], "values": ' || json_agg(json_build_array(time,value))  || ' }] }'
   AS v FROM results1     
 UNION ALL
   SELECT ',{ "series": [{ "name": "mw-f10.cpu.nice", "columns": ["time", "value"], "values": ' || json_agg(json_build_array(time,value))  || ' }] }'
   AS v FROM results2     
 UNION ALL
   SELECT ',{ "series": [{ "name": "mw-f10.cpu.system", "columns": ["time", "value"], "values": ' || json_agg(json_build_array(time,value))  || ' }] }'
   AS v FROM results3      
 UNION ALL
   SELECT ',{ "series": [{ "name": "mw-f10.cpu.interrupt", "columns": ["time", "value"], "values": ' || json_agg(json_build_array(time,value))  || ' }] }'
   AS v FROM results4     
 UNION ALL
 SELECT ']}' AS v
)
SELECT string_agg(v,'') AS ret FROM results
```

![Example cpu graph](/pics/metrics-cpu.png)



### if

```
{
   "_id": "344306990d4f3590bb779b66d367bf03",
   "_rev": "1-da39d493cfee541fc1bfec0b04212aae",
   "name": "mw-f10.if.re0",
   "type": "if",
   "ts": 1445110010,
   "ipackets": 280896271,
   "opackets": 257715916,
   "ibytes": 214015570267,
   "obytes": 126157589284,
   "imcasts": 590518,
   "omcasts": 0,
   "ierrors": 0,
   "oerrors": 0,
   "collisions": 0,
   "drops": 0
}
```

```
WITH   
results_ibytes AS (
   SELECT (doc->>'ts')::numeric * 1000 as time,  
          ((doc->>'ibytes')::numeric - lag((doc->>'ibytes')::numeric, 1) OVER w) / ((doc->>'ts')::numeric - lag((doc->>'ts')::numeric, 1) OVER w)::numeric AS ibytes_per_sec
   FROM all_metrics        
   WHERE  doc #>> '{name}'='mw-f10.if.re0'    
   AND ( to_timestamp((doc->>'ts')::numeric) > now() - interval '24h')
   WINDOW w AS (ORDER BY (doc->>'ts')::numeric)   
   ORDER BY time    
),  
results_obytes AS (   
   SELECT (doc->>'ts')::numeric * 1000 as time,   
          ((doc->>'obytes')::numeric - lag((doc->>'obytes')::numeric, 1) OVER w) / ((doc->>'ts')::numeric - lag((doc->>'ts')::numeric, 1) OVER w)::numeric AS obytes_per_sec
   FROM all_metrics     
   WHERE  doc #>> '{name}'='mw-f10.if.re0'    
   AND ( to_timestamp((doc->>'ts')::numeric) > now() - interval '24h')   
   WINDOW w AS (ORDER BY (doc->>'ts')::numeric)   
   ORDER BY time   
),   
results_ipackets AS (   
   SELECT (doc->>'ts')::numeric * 1000 as time,  
          ((doc->>'ipackets')::numeric - lag((doc->>'ipackets')::numeric, 1) OVER w) / ((doc->>'ts')::numeric - lag((doc->>'ts')::numeric, 1) OVER w)::numeric AS ipackets_per_sec  
   FROM all_metrics    
   WHERE  doc #>> '{name}'='mw-f10.if.re0'   
   AND ( to_timestamp((doc->>'ts')::numeric) > now() - interval '24h')
   WINDOW w AS (ORDER BY (doc->>'ts')::numeric)  
   ORDER BY time    
), 
results_opackets AS (   
   SELECT (doc->>'ts')::numeric * 1000 as time,  
          ((doc->>'opackets')::numeric - lag((doc->>'opackets')::numeric, 1) OVER w) / ((doc->>'ts')::numeric - lag((doc->>'ts')::numeric, 1) OVER w)::numeric AS opackets_per_sec   
   FROM all_metrics     
   WHERE  doc #>> '{name}'='mw-f10.if.re0'  
   AND ( to_timestamp((doc->>'ts')::numeric) > now() - interval '24h')   
   WINDOW w AS (ORDER BY (doc->>'ts')::numeric)   
   ORDER BY time    
),   

results AS (    
  SELECT '{ "results": [' AS v     
  UNION ALL
    SELECT '{ "series": [{ "name": "mw-f10.if.re0.ibytes_per_sec", "columns": ["time", "value"], "values": ' || json_agg(json_build_array(time,round(ibytes_per_sec,2)))  || ' }] }'     
    AS v FROM results_ibytes    
  UNION ALL
    SELECT ',{ "series": [{ "name": "mw-f10.if.re0.obytes_per_sec", "columns": ["time", "value"], "values": ' || json_agg(json_build_array(time,round(obytes_per_sec,2)))  || ' }] }'    
    AS v FROM results_obytes    
  UNION ALL
    SELECT ',{ "series": [{ "name": "mw-f10.if.re0.ipackets_per_sec", "columns": ["time", "value"], "values": ' || json_agg(json_build_array(time,round(ipackets_per_sec,2)))  || ' }] }'  
    AS v FROM results_ipackets    
  UNION ALL
    SELECT ',{ "series": [{ "name": "mw-f10.if.re0.opackets_per_sec", "columns": ["time", "value"], "values": ' || json_agg(json_build_array(time,round(opackets_per_sec,2)))  || ' }] }'
    AS v FROM results_opackets    
  UNION ALL
  SELECT ']}' AS v   
)  
SELECT string_agg(v,'') AS ret FROM results
```

![Example if graph](/pics/metrics-if.png)


### mem

```
{
   "_id": "3174aa1f4c88f1eb9df4750ca7009007",
   "_rev": "1-389c3f9546bc12d84768c504410b86b1",
   "name": "mw-f10.mem",
   "type": "mem",
   "ts": 1445190779,
   "real_active": 1003450368,
   "real_total": 3484020736,
   "free": 748453888,
   "swap_used": 133165056,
   "swap_total": 10737414144
}
```

```
WITH     
results1 AS (
  SELECT (doc->>'ts')::numeric * 1000 AS time, ROUND((doc->>'real_active')::numeric/1000000000,2) AS value 
  FROM all_metrics 
  WHERE doc #>> '{name}'='mw-f10.mem' 
  ORDER BY time
),     
results2 AS (
  SELECT (doc->>'ts')::numeric * 1000 AS time, ROUND((doc->>'real_total')::numeric/1000000000,2) AS value 
  FROM all_metrics  
  WHERE doc #>> '{name}'='mw-f10.mem' 
  ORDER BY time
),    
results3 AS (
  SELECT (doc->>'ts')::numeric * 1000 AS time,  ROUND((doc->>'free')::numeric/1000000000,2) as value 
  FROM all_metrics  
  WHERE doc #>> '{name}'='mw-f10.mem' 
  ORDER BY time
),    
results4 AS (
  SELECT (doc->>'ts')::numeric * 1000 AS time,  ROUND((doc->>'swap_used')::numeric/1000000000,2) as value 
  FROM all_metrics  
  WHERE doc #>> '{name}'='mw-f10.mem' 
  ORDER BY time
),    
results5 AS (
  SELECT (doc->>'ts')::numeric * 1000 AS time,  ROUND((doc->>'swap_total')::numeric/1000000000,2) as value 
  FROM all_metrics  
  WHERE doc #>> '{name}'='mw-f10.mem'
  ORDER BY time
),     
  
results AS (        
  SELECT '{ "results": [' AS v         
  UNION ALL
    SELECT '{ "series": [{ "name": "mw-f10.mem.real_active", "columns": ["time", "value"],  "values": ' || json_agg(json_build_array(time,value))  || ' }] }'
    AS v FROM results1      
  UNION ALL
    SELECT ',{ "series": [{ "name": "mw-f10.mem.real_total", "columns": ["time", "value"],  "values": ' || json_agg(json_build_array(time,value))  || ' }] }'
    AS v FROM results2      
  UNION ALL
    SELECT ',{ "series": [{ "name": "mw-f10.mem.free", "columns": ["time", "value"],  "values": ' || json_agg(json_build_array(time,value))  || ' }] }'
    AS v FROM results3     
  UNION ALL
    SELECT ',{ "series": [{ "name": "mw-f10.mem.swap_used",  "columns": ["time", "value"],  "values": ' || json_agg(json_build_array(time,value))  || ' }] }'
    AS v FROM results4       
  UNION ALL
    SELECT ',{ "series": [{ "name": "mw-f10.mem.swap_total",  "columns": ["time", "value"],  "values": ' || json_agg(json_build_array(time,value))  || ' }] }'
    AS v FROM results5   
  UNION ALL
  SELECT ']}' AS v   
)  
SELECT string_agg(v,'') AS ret FROM results
```

![Example mem graph](/pics/metrics-mem.png)


### io

```
{
   "_id": "344306990d4f3590bb779b66d367ba0a",
   "_rev": "1-da363ebb96f968bcd72c2f85a1c2196a",
   "name": "mw-f10.io.ada0",
   "type": "io",
   "ts": 1445110010,
   "rxfer": 63319027,
   "wxfer": 182750809,
   "seeks": 0,
   "rbytes": 373614199808,
   "wbytes": 2922737373696
}
```

```
WITH     
results_ada0_rbytes AS  (
  SELECT (doc->>'ts')::numeric * 1000 AS  time, ((doc->>'rbytes')::numeric - lag((doc->>'rbytes')::numeric, 1) OVER w) / ((doc->>'ts')::numeric - lag((doc->>'ts')::numeric, 1) OVER w)::numeric AS  rbytes_per_sec   
  FROM all_metrics  
  WHERE  doc #>> '{name}'='mw-f10.io.ada0' 
  WINDOW w AS  (ORDER BY (doc->>'ts')::numeric)   
  ORDER BY time
), 
results_ada0_wbytes AS  (
  SELECT (doc->>'ts')::numeric * 1000 AS  time, ((doc->>'wbytes')::numeric - lag((doc->>'wbytes')::numeric, 1) OVER w) / ((doc->>'ts')::numeric - lag((doc->>'ts')::numeric, 1) OVER w)::numeric AS wbytes_per_sec 
  FROM all_metrics   
  WHERE  doc #>> '{name}'='mw-f10.io.ada0'
  WINDOW w AS  (ORDER BY (doc->>'ts')::numeric)   
  ORDER BY time 
),    

results AS  (    
  SELECT '{ "results": [' AS  v     
  UNION ALL
    SELECT '{ "series": [{ "name": "mw-f10.io.ada0.read_mb_per_sec", "columns": ["time", "value"], "values": ' || json_agg(json_build_array(time,round(rbytes_per_sec/1000000,2)))  || ' }] }'     
    AS  v FROM results_ada0_rbytes    
  UNION ALL
    SELECT ',{ "series": [{ "name": "mw-f10.io.ada0.write_mb_per_sec", "columns": ["time", "value"], "values": ' || json_agg(json_build_array(time,round(wbytes_per_sec/1000000,2)))  || ' }] }'     
    AS  v FROM results_ada0_wbytes    
  UNION ALL
  SELECT ']}' AS  v   
)  
SELECT string_agg(v,'') AS  ret FROM results
```

![Example io graph](/pics/metrics-io.png)



### statsd counter metric example

```
{
   "_id": "e832faf5b9421d53f7da348755db8e09",
   "_rev": "1-3b6906d2712b795411c1e0f3405f6d7c",
   "type": "counter",
   "name": "statsd.packets_received",
   "count": 7003,
   "ts": 1424734183
}
```

```
WITH 
result1 AS (
  SELECT (doc->>'ts')::numeric * 1000 AS time, (doc->>'count')::numeric AS value 
  FROM aatest 
  WHERE doc->>'name'='statsd.packets_received' 
  AND (doc->>'count')::numeric > 0 
  ORDER BY time
), 
results AS (
  SELECT '{ "results": [' AS v 
  UNION ALL 
  SELECT '{ "series": [{ "name": "statsd.packets_received", "columns": ["time", "count"], "values": ' || json_agg(json_build_array(time,value))  || ' }] }' AS v FROM result1 
  UNION ALL 
  SELECT ']}' AS v 
) 
SELECT string_agg(v,'') AS ret FROM results
```

![Example statsd graph](/pics/metrics-statsd.png)


## Simple POST to couchdb metric host with curl

```
echo "{ \"name\": \"myhost.mymetric\", \"type\": \"mymetric\", \"ts\": `date +%s`, \"value\": 321 }" | \
curl -s -H "Accept: application/json" -H 'Content-Type: application/json' -X POST -d @- http://192.168.3.21:5984/abtest
```

Will add the below metric doc:
```
{
   "_id": "3ad893cb4cf1560add7b4caffd4b6515",
   "_rev": "1-eaccefb96599f0543cf5053ffb36595d",
   "name": "myhost.mymetric",
   "type": "mymetric",
   "ts": 1445787153,
   "value": 321
}
```


## TODO

Simple stuff to do:

Do something about grafana time sql issue (see notes on ```timeFilter``` and  ```$interval``` on https://github.com/sysadminmike/postgres-influx-mimic)

Alter grafana sql entry field to a memo/textarea to and allow for new lines to make sql editing simpler.

Perhaps simplify sql creation with pg function? 

Needs a better name - suggestions please.



Further metrics data sources ideas:

snmp - add metric data from snmp source

fluentd - https://github.com/ixixi/fluent-plugin-couch - log stuff instead of logstash and elasticsearch

make a grafana panel to search log stuff like kibana/splunk - with filter box to pass filter text to sql like $interval for time - so graphs and logs can be viewed on the same dashboard and at the same time - help please

maybe add a filer $text for sql like $interval on normal graph panel for quick drill down without having to edit all sql - help please

example pouchdb to couchdb collecting metrics from mobile device / web browser 

example rollup stuff for aggregate/archiving/make new tables in postgres based on timestamp - pg function(s) to be run periodically to automate? - note with over 2 million docs the dashboard with 6 graphs and multiple series takes under 3 secs to redraw all of them with where clause on the timestamps at 24hrs so all datapoints for last 24hrs are being loaded. - note on http_pgsql extension to deal with managing/archivng couchdbs.

