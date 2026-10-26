-- 03_union_censuses.sql
-- Purpose: combine the 1995, 2005 and 2015 NYC street tree censuses into one
--          harmonised dataset and measure the effect of the cleaning rules.
--
-- Harmonisation choices:
--   * Common columns: census_year, borough, species (common name), status, dbh.
--   * Diameter: `diameter` in 1995, `tree_dbh` in 2005 and 2015 (inches).
--   * Borough: `borough` in 1995, `boroname` in 2005 and 2015.
--     In 2005, Staten Island is stored as '5' (borocode 5), so it is recoded.
--
-- Cleaning rules (flags, so no row is deleted and the effect stays measurable):
--   * valid_diameter: 0 < dbh <= 100 inches (removes zeros, negatives and typos).
--   * living_tree: status is not 'Dead', 'Stump' or 'Planting Space'.
--     Only living trees can grow, and many dead trees and stumps still have a
--     positive diameter, so the diameter rule alone is not enough.
--
-- Check: avg_diameter_only should match the preliminary averages
--        (12.00 in 1995, 12.84 in 2005, 11.57 in 2015).

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

flagged AS (
  SELECT
    *,
    (dbh > 0 AND dbh <= 100) AS valid_diameter,
    (IFNULL(status, 'Unknown') NOT IN ('Dead', 'Stump', 'Planting Space')) AS living_tree
  FROM all_trees
)

SELECT
  census_year,
  COUNT(*) AS n_total,
  COUNTIF(valid_diameter) AS n_valid_diameter,
  ROUND(AVG(IF(valid_diameter, dbh, NULL)), 2) AS avg_diameter_only,
  COUNTIF(valid_diameter AND living_tree) AS n_clean,
  ROUND(AVG(IF(valid_diameter AND living_tree, dbh, NULL)), 2) AS avg_clean,
  COUNTIF(valid_diameter AND NOT living_tree) AS n_removed_by_status_only
FROM flagged
GROUP BY census_year
ORDER BY census_year;
