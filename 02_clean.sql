-- 02_clean.sql
-- Purpose: find the values that would distort the comparison between censuses
--          (missing values, zeros, negative values, extreme diameters, dead trees)
--          and choose the cleaning rules.
-- Run each part separately: select its text, then click Run.
--
-- Cleaning rules chosen (applied in 03_union_censuses.sql and later queries):
--   * 0 < diameter <= 100 inches
--       - zero and negative diameters are not measurements of living trees;
--       - the 100-inch threshold removes the typing errors (values up to
--         2,100 in 2005 and 450 in 2015) and under 0.02% of each census.
--   * status is not 'Dead', 'Stump' or 'Planting Space'
--       - only living trees can grow, and many dead trees and stumps still
--         have a positive diameter.

-- ---------------------------------------------------------------------------
-- Part 1: profile of the diameter column in each census
-- ---------------------------------------------------------------------------
SELECT
  '1995' AS census_year,
  COUNT(*) AS n_trees,
  COUNTIF(diameter IS NULL) AS n_null,
  COUNTIF(diameter = 0) AS n_zero,
  COUNTIF(diameter < 0) AS n_negative,
  MIN(diameter) AS min_diameter,
  MAX(diameter) AS max_diameter,
  ROUND(AVG(diameter), 2) AS avg_diameter
FROM `bigquery-public-data.new_york_trees.tree_census_1995`
UNION ALL
SELECT
  '2005',
  COUNT(*),
  COUNTIF(tree_dbh IS NULL),
  COUNTIF(tree_dbh = 0),
  COUNTIF(tree_dbh < 0),
  MIN(tree_dbh),
  MAX(tree_dbh),
  ROUND(AVG(tree_dbh), 2)
FROM `bigquery-public-data.new_york_trees.tree_census_2005`
UNION ALL
SELECT
  '2015',
  COUNT(*),
  COUNTIF(tree_dbh IS NULL),
  COUNTIF(tree_dbh = 0),
  COUNTIF(tree_dbh < 0),
  MIN(tree_dbh),
  MAX(tree_dbh),
  ROUND(AVG(tree_dbh), 2)
FROM `bigquery-public-data.new_york_trees.tree_census_2015`;


-- ---------------------------------------------------------------------------
-- Part 2: the largest diameters in each census
-- ---------------------------------------------------------------------------
-- Values far above any realistic trunk size are probably typing errors.

-- 1995
SELECT diameter, COUNT(*) AS n_trees
FROM `bigquery-public-data.new_york_trees.tree_census_1995`
GROUP BY diameter
ORDER BY diameter DESC
LIMIT 15;

-- 2005
SELECT tree_dbh, COUNT(*) AS n_trees
FROM `bigquery-public-data.new_york_trees.tree_census_2005`
GROUP BY tree_dbh
ORDER BY tree_dbh DESC
LIMIT 15;

-- 2015
SELECT tree_dbh, COUNT(*) AS n_trees
FROM `bigquery-public-data.new_york_trees.tree_census_2015`
GROUP BY tree_dbh
ORDER BY tree_dbh DESC
LIMIT 15;


-- ---------------------------------------------------------------------------
-- Part 3: compare candidate outlier thresholds and measure the effect of the
--         diameter rule (0 < diameter <= 100 inches)
-- ---------------------------------------------------------------------------
WITH all_diameters AS (
  SELECT '1995' AS census_year, diameter AS dbh
  FROM `bigquery-public-data.new_york_trees.tree_census_1995`
  UNION ALL
  SELECT '2005', tree_dbh
  FROM `bigquery-public-data.new_york_trees.tree_census_2005`
  UNION ALL
  SELECT '2015', tree_dbh
  FROM `bigquery-public-data.new_york_trees.tree_census_2015`
)
SELECT
  census_year,
  COUNT(*) AS n_total,
  COUNTIF(dbh <= 0) AS n_zero_or_negative,
  COUNTIF(dbh > 50) AS over_50,
  COUNTIF(dbh > 100) AS over_100,
  COUNTIF(dbh > 150) AS over_150,
  COUNTIF(dbh > 0 AND dbh <= 100) AS n_kept,
  ROUND(AVG(IF(dbh > 0 AND dbh <= 100, dbh, NULL)), 2) AS avg_clean
FROM all_diameters
GROUP BY census_year
ORDER BY census_year;


-- ---------------------------------------------------------------------------
-- Part 4: borough and status values, and where the zero diameters come from
-- ---------------------------------------------------------------------------
-- n_zero_or_negative shows which statuses the zero diameters belong to
-- (empty planting spaces in 1995, stumps in 2015, dead trees in 2005).
-- It also shows that Staten Island is stored as '5' in the 2005 census.
WITH all_trees AS (
  SELECT '1995' AS census_year, borough AS borough_raw, status, spc_common, diameter AS dbh
  FROM `bigquery-public-data.new_york_trees.tree_census_1995`
  UNION ALL
  SELECT '2005', boroname, status, spc_common, tree_dbh
  FROM `bigquery-public-data.new_york_trees.tree_census_2005`
  UNION ALL
  SELECT '2015', boroname, status, spc_common, tree_dbh
  FROM `bigquery-public-data.new_york_trees.tree_census_2015`
)
SELECT census_year, 'borough' AS field, borough_raw AS field_value,
       COUNT(*) AS n_trees, COUNTIF(dbh <= 0) AS n_zero_or_negative
FROM all_trees
GROUP BY census_year, borough_raw
UNION ALL
SELECT census_year, 'status', status,
       COUNT(*), COUNTIF(dbh <= 0)
FROM all_trees
GROUP BY census_year, status
ORDER BY census_year, field, field_value;
