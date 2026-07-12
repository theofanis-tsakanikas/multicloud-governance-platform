# Evidence — the private paths carried the traffic

Not a diagram. Not an assertion. The proxies' own session logs, at the one point where the two
halves of each private path meet.

Captured 2026-07-12 from `/ecs/bq-gateway-dev` and `/ecs/sql-gateway-dev` (CloudWatch, 1-day
retention — these log groups no longer exist, and neither does the stack that wrote them).

## How to read a line

```
10.11.1.17:16605  [12/Jul/2026:01:46:05.962]  api_in  api_out/googleapi4  1/3/400906  1915169  --
└─────┬────────┘                                       └────────┬───────┘             └───┬───┘
      │                                                         │                         │
      │                                                         │                    1.9 MB moved
      │                                                         └─ out to the private.googleapis.com
      │                                                            VIP (199.36.153.11), across the IPsec
      │                                                            tunnel into the GCP VPC
      └─ in from a PRIVATE address inside the GCP transit VPC (10.11.0.0/16) — via the NLB, whose only
         reachable entrance is a PrivateLink endpoint service whose ONLY allowed principal is
         arn:aws:iam::565502421330:role/private-connectivity-role-eu-central-1 — Databricks.
```

A health check carries `0` bytes. These do not.

`10.11.x` is the GCP transit hub. `10.10.x` is the Azure one. Both are private address space; neither
is routable from the internet.

## What it proves, and what it does not

It proves a real, large transfer entered from a private address and left for the target's private
endpoint. It does not, alone, prove the client was Databricks — the source address is the NLB's ENI.
Read alongside the three NCC rules in `ESTABLISHED` and the timestamps, which fall inside the pipeline
run and nowhere else, there is no other client it could have been.

## The sessions

Query (CloudWatch Logs Insights, both gateway log groups, 24h):

```
fields @timestamp
| parse @message "* [*] * * * * *" as client, ts, frontend, backend, timings, transferred_bytes, term
| filter transferred_bytes > 5000
| sort transferred_bytes desc
| display @timestamp, client, backend, transferred_bytes
| limit 15
```

131 sessions matched, out of 8,370 log lines. The other 8,239 were health checks.

```
2026-07-12T00:34:10 10.11.2.165:19360 [12/Jul/2026:00:34:03.319] api_in api_out/googleapi1 1/2/7528 7156 -- 1/1/0/0/0 0/0
2026-07-12T00:34:10 10.11.2.165:45092 [12/Jul/2026:00:34:03.415] api_in api_out/googleapi2 1/4/7431 6050 -- 2/2/1/0/0 0/0
2026-07-12T00:34:50 10.11.2.165:36121 [12/Jul/2026:00:34:40.165] api_in api_out/googleapi1 1/3/10049 6006 -- 1/1/0/0/0 0/0
2026-07-12T00:34:50 10.11.2.165:51824 [12/Jul/2026:00:34:40.213] api_in api_out/googleapi2 1/3/10000 5164 -- 2/2/1/0/0 0/0
2026-07-12T01:17:35 10.11.2.165:13317 [12/Jul/2026:01:17:27.152] api_in api_out/googleapi3 1/3/8152 6110 -- 6/6/5/1/0 0/0
2026-07-12T01:17:35 10.11.2.165:26720 [12/Jul/2026:01:17:25.253] api_in api_out/googleapi4 1/2/10054 7168 -- 4/4/3/0/0 0/0
2026-07-12T01:17:35 10.11.2.165:34630 [12/Jul/2026:01:17:25.308] api_in api_out/googleapi2 1/3/9998 6971 -- 5/5/4/1/0 0/0
2026-07-12T01:17:35 10.11.2.165:37750 [12/Jul/2026:01:17:25.253] api_in api_out/googleapi1 1/3/10056 8475 -- 3/3/2/0/0 0/0
2026-07-12T01:17:40 10.11.2.165:25637 [12/Jul/2026:01:17:27.110] api_in api_out/googleapi2 1/3/13203 11554 -- 1/1/0/0/0 0/0
2026-07-12T01:17:40 10.11.2.165:37572 [12/Jul/2026:01:17:25.309] api_in api_out/googleapi3 1/3/15001 8861 -- 2/2/1/0/0 0/0
2026-07-12T01:20:44 10.11.1.17:53156 [12/Jul/2026:01:20:34.370] api_in api_out/googleapi3 1/2/10047 6005 -- 1/1/0/0/0 0/0
2026-07-12T01:20:44 10.11.1.17:58858 [12/Jul/2026:01:20:34.414] api_in api_out/googleapi4 1/3/9998 5228 -- 2/2/1/0/0 0/0
2026-07-12T01:31:14 10.11.2.165:61972 [12/Jul/2026:01:31:02.605] api_in api_out/googleapi1 1/3/11461 10153 -- 4/4/3/1/0 0/0
2026-07-12T01:31:14 10.11.2.165:8848 [12/Jul/2026:01:31:02.688] api_in api_out/googleapi2 1/3/11379 9186 -- 3/3/2/1/0 0/0
2026-07-12T01:35:08 10.11.2.165:46859 [12/Jul/2026:01:31:07.672] api_in api_out/googleapi1 1/4/240438 5566 -- 2/2/1/0/0 0/0
2026-07-12T01:35:10 10.11.1.17:4987 [12/Jul/2026:01:31:10.422] api_in api_out/googleapi2 1/3/240413 382364 -- 1/1/0/0/0 0/0
2026-07-12T01:43:30 10.11.1.17:42373 [12/Jul/2026:01:43:20.278] api_in api_out/googleapi4 1/3/10065 5861 -- 1/1/0/0/0 0/0
2026-07-12T01:43:30 10.11.1.17:57367 [12/Jul/2026:01:43:20.348] api_in api_out/googleapi1 1/2/9994 5403 -- 2/2/1/0/0 0/0
2026-07-12T01:43:42 10.11.1.17:13251 [12/Jul/2026:01:43:32.521] api_in api_out/googleapi1 1/4/9998 5433 -- 2/2/1/0/0 0/0
2026-07-12T01:43:42 10.11.1.17:60162 [12/Jul/2026:01:43:32.476] api_in api_out/googleapi4 1/3/10045 5926 -- 1/1/0/0/0 0/0
2026-07-11T22:48:29 10.10.2.56:64393 [11/Jul/2026:22:48:28.805] sql_in sql_out/azuresql 1/10/295 10751 -- 1/1/0/0/0 0/0
2026-07-12T00:50:51 10.10.1.41:20797 [12/Jul/2026:00:50:51.645] sql_in sql_out/azuresql 1/13/140 10330 -- 2/2/1/1/0 0/0
2026-07-12T00:50:51 10.10.1.41:38675 [12/Jul/2026:00:50:51.342] sql_in sql_out/azuresql 1/11/309 10378 -- 2/2/1/1/0 0/0
2026-07-12T00:50:51 10.10.1.41:47088 [12/Jul/2026:00:50:51.780] sql_in sql_out/azuresql 1/10/152 10348 -- 2/2/1/1/0 0/0
2026-07-12T00:50:52 10.10.1.41:46933 [12/Jul/2026:00:50:51.927] sql_in sql_out/azuresql 1/11/125 10342 -- 1/1/0/0/0 0/0
2026-07-12T00:50:54 10.10.1.41:10496 [12/Jul/2026:00:50:54.615] sql_in sql_out/azuresql 1/11/118 10125 -- 1/1/0/0/0 0/0
2026-07-12T00:50:54 10.10.1.41:24525 [12/Jul/2026:00:50:54.505] sql_in sql_out/azuresql 1/10/112 10125 -- 2/2/1/1/0 0/0
2026-07-12T00:50:55 10.10.1.41:48204 [12/Jul/2026:00:50:54.925] sql_in sql_out/azuresql 1/11/437 202728 -- 1/1/0/0/0 0/0
2026-07-12T00:50:55 10.10.1.41:52410 [12/Jul/2026:00:50:55.504] sql_in sql_out/azuresql 1/10/415 202728 -- 1/1/0/0/0 0/0
2026-07-12T00:50:55 10.10.1.41:61699 [12/Jul/2026:00:50:54.924] sql_in sql_out/azuresql 1/11/375 10894 -- 2/2/1/1/0 0/0
2026-07-12T01:16:18 10.10.2.56:36549 [12/Jul/2026:01:16:18.707] sql_in sql_out/azuresql 1/9/250 10378 -- 2/2/1/1/0 0/0
2026-07-12T01:16:19 10.10.2.56:39390 [12/Jul/2026:01:16:19.245] sql_in sql_out/azuresql 1/10/152 10348 -- 1/1/0/0/0 0/0
2026-07-12T01:16:19 10.10.2.56:48725 [12/Jul/2026:01:16:19.101] sql_in sql_out/azuresql 1/10/149 10342 -- 2/2/1/1/0 0/0
2026-07-12T01:16:19 10.10.2.56:7980 [12/Jul/2026:01:16:18.952] sql_in sql_out/azuresql 1/9/152 10330 -- 2/2/1/1/0 0/0
2026-07-12T01:16:20 10.10.2.56:12233 [12/Jul/2026:01:16:20.878] sql_in sql_out/azuresql 1/9/108 10125 -- 1/1/0/0/0 0/0
2026-07-12T01:16:20 10.10.2.56:12993 [12/Jul/2026:01:16:20.762] sql_in sql_out/azuresql 1/10/120 10125 -- 2/2/1/1/0 0/0
2026-07-12T01:16:21 10.10.2.56:10898 [12/Jul/2026:01:16:21.204] sql_in sql_out/azuresql 1/11/327 10894 -- 2/2/1/1/0 0/0
2026-07-12T01:16:21 10.10.2.56:13286 [12/Jul/2026:01:16:21.205] sql_in sql_out/azuresql 1/10/393 202728 -- 1/1/0/0/0 0/0
2026-07-12T01:16:22 10.10.2.56:3304 [12/Jul/2026:01:16:21.747] sql_in sql_out/azuresql 1/10/388 202728 -- 1/1/0/0/0 0/0
2026-07-12T01:20:42 10.10.1.41:31211 [12/Jul/2026:01:20:42.137] sql_in sql_out/azuresql 1/11/149 10751 -- 1/1/0/0/0 0/0
```
