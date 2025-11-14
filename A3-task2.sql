SET search_path TO ptv;

DROP TABLE IF EXISTS mb2021_mel CASCADE;

CREATE TABLE mb2021_mel AS
SELECT *
FROM mb_2021
WHERE gcc_name21 ILIKE 'Greater Melbourne%';

CREATE INDEX IF NOT EXISTS mb2021_mel_geom_gix ON mb2021_mel USING GIST (geom);

SELECT COUNT(*) AS mel_mb_count FROM mb2021_mel;
SELECT * FROM mb2021_mel;

---2
SET search_path TO ptv, public;

ALTER TABLE stops DROP COLUMN IF EXISTS geom;

-- 2) 添加几何列（GDA2020: EPSG 7844）
ALTER TABLE stops ADD COLUMN geom geometry(Point, 7844);

UPDATE stops
SET geom = ST_Transform(
             ST_SetSRID(ST_MakePoint(stop_lon, stop_lat), 4326),
             7844
           )
WHERE stop_lon IS NOT NULL
  AND stop_lat IS NOT NULL
  AND stop_lon BETWEEN -180 AND 180
  AND stop_lat BETWEEN  -90 AND  90;

-- 4) 为几何列建空间索引（后续空间筛选/可视化更快）
CREATE INDEX IF NOT EXISTS stops_geom_gix ON stops USING GIST (geom);

-- 删除旧表
DROP TABLE IF EXISTS stops_routes_mel CASCADE;

CREATE TABLE stops_routes_mel AS
SELECT DISTINCT
  s.stop_id,
  s.stop_name,
  s.geom,                                      
  r.route_short_name AS route_number,          -- Route short name
  r.route_long_name  AS route_name,            -- Route long name
  r.route_type       AS vehicle_type
FROM stops s
JOIN stop_times st  ON s.stop_id = st.stop_id
JOIN trips t        ON t.trip_id = st.trip_id
JOIN routes r       ON r.route_id = t.route_id
WHERE r.route_type = 3;                        -- Bus only
CREATE INDEX IF NOT EXISTS stops_routes_mel_geom_gix ON stops_routes_mel USING GIST (geom);

-- 检查记录数
SELECT COUNT(*) AS mel_bus_stop_count FROM stops_routes_mel;

--Step 3：空间过滤（仅限 Melbourne Metropolitan 区域）
-- 筛选只在 Greater Melbourne 范围内的 Bus Stops
DROP TABLE IF EXISTS stops_routes_mel_final CASCADE;

CREATE TABLE stops_routes_mel_final AS
SELECT srm.*
FROM stops_routes_mel srm
JOIN mb2021_mel mb
  ON ST_Intersects(srm.geom, mb.geom);

CREATE INDEX IF NOT EXISTS stops_routes_mel_final_geom_gix ON stops_routes_mel_final USING GIST (geom);

SELECT COUNT(*) AS mel_final_stop_count FROM stops_routes_mel_final;

select * from stops;
SELECT * FROM stops_routes_mel;

SELECT * FROM stops_routes_mel_final;

---finalize table as stops_routes_mel
-- 1️⃣ 删除旧表 stops_routes_mel（保留 final）
DROP TABLE IF EXISTS stops_routes_mel CASCADE;

-- 2️⃣ 用 stops_routes_mel_final 重新建新表（同名）
--     并把 vehicle_type 转成文字、geom 保留原几何
CREATE TABLE stops_routes_mel AS
SELECT
  stop_id,
  stop_name,
  geom,
  route_number,
  route_name,
  CASE 
    WHEN vehicle_type = 0 THEN 'Tram/Light rail'
    WHEN vehicle_type = 1 THEN 'Subway/Metro'
    WHEN vehicle_type = 2 THEN 'Rail'
    WHEN vehicle_type = 3 THEN 'Bus'
    WHEN vehicle_type = 4 THEN 'Ferry'
    WHEN vehicle_type = 5 THEN 'Cable tram'
    WHEN vehicle_type = 6 THEN 'Aerial lift'
    WHEN vehicle_type = 7 THEN 'Funicular'
    WHEN vehicle_type = 11 THEN 'Trolleybus'
    WHEN vehicle_type = 12 THEN 'Monorail'
    ELSE 'Other'
  END AS vehicle
FROM ptv.stops_routes_mel_final;

-- 3️⃣ 为新表添加空间索引
CREATE INDEX IF NOT EXISTS stops_routes_mel_geom_gix ON ptv.stops_routes_mel USING GIST (geom);

-- 4️⃣ 验证结果
SELECT COUNT(*) AS row_count FROM ptv.stops_routes_mel;

SELECT stop_id, stop_name, ST_AsText(geom) AS geom, route_number, route_name, vehicle
FROM ptv.stops_routes_mel;

--further exploration:EMPLOYMENT
select * from mb2021_mel;
DROP TABLE IF EXISTS fa_industrial_mb CASCADE;
CREATE TABLE fa_industrial_mb AS
SELECT
  mb.mb_code21,
  mb.mb_cat21,
  mb.areasqkm21,
  COUNT(srm.stop_id) AS stop_count,
  COUNT(srm.stop_id)/NULLIF(mb.areasqkm21,0) AS stop_density_per_km2,
  mb.geom
FROM ptv.mb2021_mel mb
LEFT JOIN ptv.stops_routes_mel srm
  ON ST_Intersects(mb.geom, srm.geom)
WHERE mb.mb_cat21 IN ('Industrial','Primary Production')
GROUP BY mb.mb_code21, mb.mb_cat21, mb.areasqkm21, mb.geom;
commit;
select * from fa_industrial_mb;