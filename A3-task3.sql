SET search_path TO ptv, public;



-- 1️⃣ 工业 & 生产类 Mesh Blocks 的站点数量与密度
DROP TABLE IF EXISTS ta_ind_mb_density CASCADE;
CREATE TABLE ta_ind_mb_density AS
SELECT
  mb.mb_code21,
  mb.mb_cat21,
  mb.areasqkm21,
  COUNT(s.stop_id) AS stop_count,
  COUNT(s.stop_id)/NULLIF(mb.areasqkm21,0) AS stop_density_per_km2,
  mb.geom
FROM mb2021_mel mb
LEFT JOIN stops_routes_mel s
  ON ST_Intersects(mb.geom, s.geom)
WHERE mb.mb_cat21 IN ('Industrial','Primary Production')
GROUP BY mb.mb_code21, mb.mb_cat21, mb.areasqkm21, mb.geom;

CREATE INDEX IF NOT EXISTS ta_ind_mb_density_gix ON ta_ind_mb_density USING GIST(geom);

SELECT 
  s.sal_name_2021 AS suburb_name,
  COUNT(DISTINCT m.mb_code21) AS industrial_blocks,
  ROUND(SUM(m.areasqkm21)::numeric, 2) AS area_km2
FROM mb2021_mel m
JOIN sal_2021 s ON m.mb_code21 = s.mb_code_2021
WHERE m.mb_cat21 IN ('Industrial', 'Primary Production')
GROUP BY s.sal_name_2021
HAVING COUNT(DISTINCT m.mb_code21) >= 10  
ORDER BY industrial_blocks DESC
LIMIT 20;


SELECT * FROM ta_ind_mb_density ORDER BY stop_density_per_km2 ;

SELECT * FROM ta_ind_mb_density ORDER BY stop_density_per_km2 DESC LIMIT 10;

SELECT 
  s.sal_name_2021 AS suburb_name,
  COUNT(*) AS industrial_blocks,
  ROUND(AVG(d.stop_density_per_km2)::numeric, 2) AS avg_density,
  ROUND(MAX(d.stop_density_per_km2)::numeric, 2) AS max_density,
  SUM(d.stop_count) AS total_stops
FROM ta_ind_mb_density d
JOIN sal_2021 s ON d.mb_code21 = s.mb_code_2021
WHERE d.stop_density_per_km2 > 10  
GROUP BY s.sal_name_2021
HAVING COUNT(*) >= 3  
ORDER BY avg_density DESC
LIMIT 15;

SELECT 
  s.sal_name_2021 AS suburb_name,
  COUNT(*) AS industrial_blocks,
  ROUND(AVG(d.stop_density_per_km2)::numeric, 2) AS avg_density,
  SUM(d.stop_count) AS total_stops
FROM ta_ind_mb_density d
JOIN sal_2021 s ON d.mb_code21 = s.mb_code_2021
WHERE d.stop_density_per_km2 BETWEEN 3 AND 8
GROUP BY s.sal_name_2021
HAVING COUNT(*) >= 3
ORDER BY avg_density DESC;

SELECT 
  s.sal_name_2021 AS suburb_name,
  COUNT(*) AS industrial_blocks,
  ROUND(AVG(d.stop_density_per_km2)::numeric, 2) AS avg_density,
  SUM(CASE WHEN d.stop_count = 0 THEN 1 ELSE 0 END) AS blocks_with_zero_stops
FROM ta_ind_mb_density d
JOIN sal_2021 s ON d.mb_code21 = s.mb_code_2021
WHERE d.stop_density_per_km2 < 2
GROUP BY s.sal_name_2021
HAVING COUNT(*) >= 3
ORDER BY industrial_blocks DESC
LIMIT 20;




-- 2️⃣ 工业区是否在 400 m 内存在公交站
DROP TABLE IF EXISTS ta_ind_mb_cover400 CASCADE;
CREATE TABLE ta_ind_mb_cover400 AS
SELECT
  d.mb_code21,
  EXISTS (
    SELECT 1
    FROM stops_routes_mel s
    WHERE ST_DWithin(s.geom, d.geom, 400) -- 400 m
  ) AS covered_400m
FROM ta_ind_mb_density d;

SELECT
  ROUND(AVG(CASE WHEN covered_400m THEN 1 ELSE 0 END)::numeric, 4) AS coverage_rate_400m,
  SUM(CASE WHEN covered_400m THEN 0 ELSE 1 END) AS uncovered_blocks,
  COUNT(*) AS total_blocks
FROM ta_ind_mb_cover400;

SELECT
  COUNT(*) AS total_industrial_blocks,
  SUM(CASE WHEN covered_400m THEN 1 ELSE 0 END) AS covered_blocks,
  SUM(CASE WHEN NOT covered_400m THEN 1 ELSE 0 END) AS uncovered_blocks,
  ROUND(AVG(CASE WHEN covered_400m THEN 1 ELSE 0 END)::numeric * 100, 2) AS coverage_rate_percent
FROM ta_ind_mb_cover400;

SELECT 
  s.sal_name_2021 AS suburb_name,
  COUNT(*) AS total_blocks,
  SUM(CASE WHEN NOT c.covered_400m THEN 1 ELSE 0 END) AS uncovered_blocks,
  ROUND(AVG(CASE WHEN NOT c.covered_400m THEN 1 ELSE 0 END)::numeric * 100, 1) AS uncovered_rate_percent
FROM ta_ind_mb_cover400 c
JOIN ta_ind_mb_density d ON c.mb_code21 = d.mb_code21
JOIN sal_2021 s ON d.mb_code21 = s.mb_code_2021
GROUP BY s.sal_name_2021
HAVING SUM(CASE WHEN NOT c.covered_400m THEN 1 ELSE 0 END) >= 5  -- 至少5个未覆盖块
ORDER BY uncovered_blocks DESC
LIMIT 15;






-- 重新计算基于质心的400m覆盖率
DROP TABLE IF EXISTS ta_ind_mb_cover400_centroid CASCADE;

CREATE TABLE ta_ind_mb_cover400_centroid AS
SELECT
  d.mb_code21,
  EXISTS (
    SELECT 1
    FROM stops_routes_mel s
    WHERE ST_DWithin(
      ST_Centroid(d.geom)::geography,  -- 使用质心
      s.geom::geography,
      400
    )
  ) AS covered_400m
FROM ta_ind_mb_density d;

-- 重新统计
SELECT
  COUNT(*) AS total_blocks,
  SUM(CASE WHEN covered_400m THEN 1 ELSE 0 END) AS covered_blocks,
  SUM(CASE WHEN NOT covered_400m THEN 1 ELSE 0 END) AS uncovered_blocks,
  ROUND(AVG(CASE WHEN covered_400m THEN 1 ELSE 0 END)::numeric * 100, 2) AS coverage_rate_percent
FROM ta_ind_mb_cover400_centroid;



-- 3️⃣ 每个工业 MB 到最近公交站的距离（米）
DROP TABLE IF EXISTS ta_ind_mb_nearest CASCADE;
CREATE TABLE ta_ind_mb_nearest AS
SELECT
  d.mb_code21,
  d.mb_cat21,
  d.areasqkm21,
  d.stop_count,
  d.stop_density_per_km2,
  d.geom,
  (
    SELECT ST_Distance(d.geom::geography, s.geom::geography)
    FROM stops_routes_mel s
    ORDER BY d.geom <-> s.geom
    LIMIT 1
  ) AS nearest_stop_m
FROM ta_ind_mb_density d;

SELECT mb_code21, nearest_stop_m, stop_density_per_km2
FROM ta_ind_mb_nearest
ORDER BY nearest_stop_m DESC
LIMIT 10;

SELECT 
  COUNT(*) AS total_blocks,
  ROUND(AVG(nearest_stop_m)::numeric, 2) AS mean_distance_m,
  ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY nearest_stop_m)::numeric, 2) AS median_distance_m,
  ROUND(MIN(nearest_stop_m)::numeric, 2) AS min_distance_m,
  ROUND(MAX(nearest_stop_m)::numeric, 2) AS max_distance_m
FROM ta_ind_mb_nearest;

SELECT 
  n.mb_code21,
  s.sal_name_2021 AS suburb_name,
  ROUND(n.nearest_stop_m::numeric, 2) AS distance_m,
  ROUND(n.stop_density_per_km2::numeric, 2) AS stop_density
FROM ta_ind_mb_nearest n
JOIN sal_2021 s ON n.mb_code21 = s.mb_code_2021
ORDER BY n.nearest_stop_m DESC
LIMIT 1;

SELECT 
  n.mb_code21,
  ROUND(n.nearest_stop_m::numeric, 0) AS distance_m,
  ROUND(n.stop_density_per_km2::numeric, 1) AS stop_density,
  s.sal_name_2021 AS location
FROM ta_ind_mb_nearest n
JOIN sal_2021 s ON n.mb_code21 = s.mb_code_2021
ORDER BY n.nearest_stop_m DESC
LIMIT 10;

SELECT 
  s.sal_name_2021 AS suburb_name,
  COUNT(*) AS blocks_beyond_800m,
  ROUND(AVG(n.nearest_stop_m)::numeric, 2) AS avg_distance_m,
  ROUND(MAX(n.nearest_stop_m)::numeric, 2) AS max_distance_m
FROM ta_ind_mb_nearest n
JOIN sal_2021 s ON n.mb_code21 = s.mb_code_2021
WHERE n.nearest_stop_m > 800
GROUP BY s.sal_name_2021
ORDER BY blocks_beyond_800m DESC;

SELECT 
  CASE 
    WHEN nearest_stop_m <= 200 THEN '0-200m (Excellent)'
    WHEN nearest_stop_m <= 400 THEN '200-400m (Good)'
    WHEN nearest_stop_m <= 600 THEN '400-600m (Moderate)'
    WHEN nearest_stop_m <= 800 THEN '600-800m (Poor)'
    ELSE '800m+ (Very Poor)'
  END AS distance_category,
  COUNT(*) AS block_count,
  ROUND(AVG(nearest_stop_m)::numeric, 2) AS avg_distance_m
FROM ta_ind_mb_nearest
GROUP BY 
  CASE 
    WHEN nearest_stop_m <= 200 THEN '0-200m (Excellent)'
    WHEN nearest_stop_m <= 400 THEN '200-400m (Good)'
    WHEN nearest_stop_m <= 600 THEN '400-600m (Moderate)'
    WHEN nearest_stop_m <= 800 THEN '600-800m (Poor)'
    ELSE '800m+ (Very Poor)'
  END
ORDER BY avg_distance_m;


-- 4
DROP TABLE IF EXISTS ta_ind_mb_score CASCADE;

CREATE TABLE ta_ind_mb_score AS
WITH stats AS (
  SELECT
    MIN(stop_density_per_km2) AS d_min,
    MAX(stop_density_per_km2) AS d_max,
    MIN(nearest_stop_m) AS m_min,
    MAX(nearest_stop_m) AS m_max
  FROM ta_ind_mb_nearest
)
SELECT
  n.mb_code21,
  n.mb_cat21,
  n.stop_density_per_km2,
  n.nearest_stop_m,
  -- 归一化 0–1
  (n.stop_density_per_km2 - s.d_min) / NULLIF(s.d_max - s.d_min, 0) AS d_norm,
  1 - (n.nearest_stop_m - s.m_min) / NULLIF(s.m_max - s.m_min, 0) AS m_norm,
  ROUND((
    (
      ((n.stop_density_per_km2 - s.d_min) / NULLIF(s.d_max - s.d_min, 0)) +
      (1 - (n.nearest_stop_m - s.m_min) / NULLIF(s.m_max - s.m_min, 0))
    ) / 2.0
  )::numeric, 4) AS access_score,  
  n.geom
FROM ta_ind_mb_nearest n, stats s;

SELECT 
  s.sal_name_2021 AS suburb_name,
  COUNT(*) AS block_count,
  ROUND(AVG(sc.access_score)::numeric, 4) AS avg_score,
  ROUND(MIN(sc.access_score)::numeric, 4) AS min_score,
  ROUND(MAX(sc.access_score)::numeric, 4) AS max_score
FROM ta_ind_mb_score sc
JOIN sal_2021 s ON sc.mb_code21 = s.mb_code_2021
GROUP BY s.sal_name_2021
HAVING COUNT(*) >= 3
ORDER BY avg_score DESC
LIMIT 15;
SELECT 
  ROW_NUMBER() OVER (ORDER BY sc.access_score DESC) AS rank,
  sc.mb_code21,
  ROUND(sc.access_score::numeric, 4) AS score,
  s.sal_name_2021 AS suburb,
  ROUND(sc.stop_density_per_km2::numeric, 2) AS density,
  ROUND(sc.nearest_stop_m::numeric, 0) AS distance_m
FROM ta_ind_mb_score sc
JOIN sal_2021 s ON sc.mb_code21 = s.mb_code_2021
ORDER BY sc.access_score DESC
LIMIT 10;