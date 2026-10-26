-- 04_average_by_year.sql
-- Purpose: compare the diameter of living street trees across the three censuses
--          using the average, the median and the quartiles.
--
-- Cleaning rules (see 03_union_censuses.sql):
--   * 0 < dbh <= 100 inches
--   * status is not 'Dead', 'Stump' or 'Planting Space'
--
-- Why the median: the average is sensitive to extreme values and to the many
-- young trees planted between censuses. If the median moves differently from
-- the average, the distribution of diameters has changed shape.
-- APPROX_QUANTILES(dbh, 100)[OFFSET(50)] returns an approximate median.

WITH all_trees AS (
  SELECT
    1995 AS census_year,
    borough,
    spc_common AS species,
    status,
    diameter AS dbh
  FROM `bigquery-public-data.new_york_trees.tree_census_1995`

  UNION ALL

  SELECT
    2005,
    CASE boroname WHEN '5' THEN 'Staten Island' ELSE boroname END,
    spc_common,
    status,
    tree_dbh
  FROM `bigquery-public-data.new_york_trees.tree_census_2005`

  UNION ALL

  SELECT
    2015,
    boroname,
    spc_common,
    status,
    tree_dbh
  FROM `bigquery-public-data.new_york_trees.tree_census_2015`
),

clean_trees AS (
  SELECT census_year, borough, species, status, dbh
  FROM all_trees
  WHERE dbh > 0
    AND dbh <= 100
    AND IFNULL(status, 'Unknown') NOT IN ('Dead', 'Stump', 'Planting Space')
)

SELECT
  census_year,
  COUNT(*) AS n_trees,
  ROUND(AVG(dbh), 2) AS avg_dbh,
  APPROX_QUANTILES(dbh, 100)[OFFSET(25)] AS p25_dbh,
  APPROX_QUANTILES(dbh, 100)[OFFSET(50)] AS median_dbh,
  APPROX_QUANTILES(dbh, 100)[OFFSET(75)] AS p75_dbh,
  MAX(dbh) AS max_dbh
FROM clean_trees
GROUP BY census_year
ORDER BY census_year;
