CREATE SCHEMA IF NOT EXISTS ptv;
SET search_path TO ptv, public;
CREATE EXTENSION IF NOT EXISTS postgis;

-- 2) 基础表（按你提供/GTFS 常见字段，仅用到你这批 txt 里的列）

-- agency.txt（以常见 GTFS 列为准）
DROP TABLE IF EXISTS agency CASCADE;
CREATE TABLE agency (
  agency_id        TEXT PRIMARY KEY,
  agency_name      TEXT NOT NULL,
  agency_url       TEXT NOT NULL,
  agency_timezone  TEXT NOT NULL,
  agency_lang      TEXT
);

-- routes.txt（以常见 GTFS 列为准）
DROP TABLE IF EXISTS routes CASCADE;
CREATE TABLE routes (
  route_id          TEXT PRIMARY KEY,
  agency_id         TEXT,
  route_short_name  TEXT,
  route_long_name   TEXT,
  route_type        INTEGER NOT NULL,
  route_color       TEXT,
  route_text_color  TEXT,
  FOREIGN KEY (agency_id) REFERENCES agency(agency_id)
);

-- calendar.txt（固定列）
DROP TABLE IF EXISTS calendar CASCADE;
CREATE TABLE calendar (
  service_id TEXT PRIMARY KEY,
  monday     INTEGER NOT NULL,
  tuesday    INTEGER NOT NULL,
  wednesday  INTEGER NOT NULL,
  thursday   INTEGER NOT NULL,
  friday     INTEGER NOT NULL,
  saturday   INTEGER NOT NULL,
  sunday     INTEGER NOT NULL,
  start_date DATE NOT NULL,
  end_date   DATE NOT NULL
);

-- calendar_dates.txt（固定列）
DROP TABLE IF EXISTS calendar_dates CASCADE;
CREATE TABLE calendar_dates (
  service_id     TEXT NOT NULL,
  date           DATE NOT NULL,
  exception_type INTEGER NOT NULL,
  PRIMARY KEY (service_id, date),
  FOREIGN KEY (service_id) REFERENCES calendar(service_id)
);

-- stops.txt（你发来的文件仅这4列）
DROP TABLE IF EXISTS stops CASCADE;
CREATE TABLE stops (
  stop_id   TEXT not NULL,
  stop_name TEXT NOT NULL,
  stop_lat  DOUBLE PRECISION NOT NULL,
  stop_lon  DOUBLE PRECISION NOT NULL
);

-- trips.txt（若你有 trips.txt，常见列如下；若暂时没有可先跳过这段）
DROP TABLE IF EXISTS trips CASCADE;
CREATE TABLE trips (
  trip_id     TEXT PRIMARY KEY,
  route_id    TEXT NOT NULL,
  service_id  TEXT NOT NULL,
  trip_headsign TEXT,
  direction_id INTEGER,
  shape_id    TEXT,
  FOREIGN KEY (route_id)   REFERENCES routes(route_id),
  FOREIGN KEY (service_id) REFERENCES calendar(service_id)
);

-- shapes.txt（你给的字段）
DROP TABLE IF EXISTS shapes CASCADE;
CREATE TABLE shapes (
  shape_id            TEXT NOT NULL,
  shape_pt_lat        DOUBLE PRECISION NOT NULL,
  shape_pt_lon        DOUBLE PRECISION NOT NULL,
  shape_pt_sequence   INTEGER NOT NULL,
  shape_dist_traveled DOUBLE PRECISION,
  PRIMARY KEY (shape_id, shape_pt_sequence)
);

-- stop_times.txt（你给的字段）
DROP TABLE IF EXISTS stop_times CASCADE;
CREATE TABLE stop_times (
  trip_id              TEXT NOT NULL,
  arrival_time         TEXT,  -- GTFS 允许 24h+，故存 TEXT 最稳妥；若要时间运算可转成秒数存 INT
  departure_time       TEXT,
  stop_id              TEXT NOT NULL,
  stop_sequence        INTEGER NOT NULL,
  stop_headsign        TEXT,
  pickup_type          INTEGER,
  drop_off_type        INTEGER,
  shape_dist_traveled  DOUBLE PRECISION,
  PRIMARY KEY (trip_id, stop_sequence),
  FOREIGN KEY (trip_id) REFERENCES trips(trip_id)
);
--DROP TABLE IF EXISTS trips CASCADE;
--CREATE TABLE trips (
--  trip_id        TEXT not NULL,
--  route_id       TEXT NOT NULL,
--  service_id     TEXT NOT NULL,
--  shape_id       TEXT,
--  trip_headsign  TEXT,
--  direction_id   INTEGER
--);



-- 索引（查询常用）
CREATE INDEX IF NOT EXISTS idx_trips_route    ON trips(route_id);
CREATE INDEX IF NOT EXISTS idx_trips_service  ON trips(service_id);
CREATE INDEX IF NOT EXISTS idx_trips_shape    ON trips(shape_id);
-- 3) 性能相关索引（可选但推荐）
CREATE INDEX IF NOT EXISTS idx_routes_agency       ON routes(agency_id);
CREATE INDEX IF NOT EXISTS idx_trips_route         ON trips(route_id);
CREATE INDEX IF NOT EXISTS idx_trips_service       ON trips(service_id);
CREATE INDEX IF NOT EXISTS idx_stop_times_stop     ON stop_times(stop_id);
CREATE INDEX IF NOT EXISTS idx_shapes_id_seq       ON shapes(shape_id, shape_pt_sequence);

-- 4) 导入（把 /data/gtfs 改成你容器内的真实路径）
-- 注意：路径是容器内路径；需对 postgres 进程可读（容器里就没问题）
-- CSV HEADER 会自动跳过首行列名

-- 先清空（避免重复导）
TRUNCATE agency, routes, calendar, calendar_dates, stops, trips, stop_times, shapes;

COPY agency         FROM '/data/adata/gtfs/agency.txt'         WITH (FORMAT csv, HEADER true);
COPY routes         FROM '/data/adata/gtfs/routes.txt'         WITH (FORMAT csv, HEADER true);
COPY calendar       FROM '/data/adata/gtfs/calendar.txt'       WITH (FORMAT csv, HEADER true);
COPY calendar_dates FROM '/data/adata/gtfs/calendar_dates.txt' WITH (FORMAT csv, HEADER true);
COPY stops          FROM '/data/adata/gtfs/stops.txt'          WITH (FORMAT csv, HEADER true);

-- 若有 trips.txt 再执行：
-- COPY trips FROM '/data/gtfs/trips.txt' WITH (FORMAT csv, HEADER true);

-- 你提供的两张大表：
truncate table shapes;
COPY shapes FROM '/data/adata/gtfs/shapes.txt' WITH (FORMAT csv, HEADER true);
COPY stop_times FROM '/data/adata/gtfs/stop_times.txt' WITH (FORMAT csv, HEADER true);

-- 导入（列顺序与文件一致）
COPY trips (route_id, service_id, trip_id, shape_id, trip_headsign, direction_id)
FROM '/data/adata/gtfs/trips.txt'
WITH (FORMAT csv, HEADER true);


TRUNCATE ptv.stop_times;

DROP TABLE IF EXISTS ptv.stop_times_raw;
CREATE TABLE ptv.stop_times_raw (
  trip_id TEXT,
  arrival_time TEXT,
  departure_time TEXT,
  stop_id TEXT,
  stop_sequence TEXT,
  stop_headsign TEXT,
  pickup_type TEXT,
  drop_off_type TEXT,
  shape_dist_traveled TEXT
);

COPY ptv.stop_times_raw
FROM '/data/adata/gtfs/stop_times.txt'
WITH (
  FORMAT csv,
  HEADER true,
  QUOTE '"',
  DELIMITER ',',
  ENCODING 'UTF8'
);
INSERT INTO ptv.stop_times
(trip_id, arrival_time, departure_time, stop_id,
 stop_sequence, stop_headsign, pickup_type, drop_off_type, shape_dist_traveled)
SELECT
  trip_id,
  arrival_time,
  departure_time,
  stop_id,
  NULLIF(stop_sequence, '')::integer,
  NULLIF(stop_headsign, ''),
  NULLIF(pickup_type, '')::integer,
  NULLIF(drop_off_type, '')::integer,
  NULLIF(REGEXP_REPLACE(shape_dist_traveled, '(^\"|\"$)', '', 'g'), '')::double precision
FROM ptv.stop_times_raw;

commit;


---
select * from agency;
select count(*) from calendar;
select * from calendar_dates;
select * from routes;
select * from shapes;
select * from stop_times;
select * from stops;
select * from trips;

---
SET search_path TO ptv, public;

-- LGA_2021
DROP TABLE IF EXISTS ptv.lga_2021 CASCADE;
CREATE TABLE ptv.lga_2021 (
  MB_CODE_2021          TEXT,         -- Mesh Block code (unique MB identifier)
  LGA_CODE_2021         TEXT,         -- LGA code
  LGA_NAME_2021         TEXT,         -- LGA name
  STATE_CODE_2021       TEXT,         -- state numeric code
  STATE_NAME_2021       TEXT,         -- state name
  AUS_CODE_2021         TEXT,         -- country code
  AUS_NAME_2021         TEXT,         -- country name
  AREA_ALBERS_SQKM      DOUBLE PRECISION, -- area in square km
  ASGS_LOCI_URI_2021    TEXT          -- URI link to official ABS dataset
);

COPY lga_2021 FROM '/data/adata/LGA_2021_AUST.csv' WITH (FORMAT csv, HEADER true);

-- SAL_2021
DROP TABLE IF EXISTS ptv.sal_2021 CASCADE;
CREATE TABLE ptv.sal_2021 (
  MB_CODE_2021          TEXT,
  SAL_CODE_2021         TEXT,
  SAL_NAME_2021         TEXT,
  STATE_CODE_2021       TEXT,
  STATE_NAME_2021       TEXT,
  AUS_CODE_2021         TEXT,
  AUS_NAME_2021         TEXT,
  AREA_ALBERS_SQKM      DOUBLE PRECISION,
  ASGS_LOCI_URI_2021    TEXT
);

COPY sal_2021 FROM '/data/adata/SAL_2021_AUST.csv' WITH (FORMAT csv, HEADER true);
---
select * from mb_2021;
select * from lga_2021;
select * from sal_2021;

---

with tbl as
(select table_schema, TABLE_NAME
 from information_schema.tables
 where table_schema in ('ptv'))
select table_schema, TABLE_NAME,
(xpath('/row/c/text()', query_to_xml(format('select count(*) as c from %I.%I', table_schema, TABLE_NAME), FALSE, TRUE, '')))[1]::text::int AS rows_n
from tbl
order by table_name; 

