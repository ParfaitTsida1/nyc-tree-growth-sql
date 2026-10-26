-- 05_by_borough_species.sql
-- Purpose: compare the diameter of living street trees by borough (part 1) and
--          by species (part 2) across the three censuses.
--          Run each part separately: select its text, then click Run.
--
-- Cleaning rules (see 03_union_censuses.sql):
--   * 0 < dbh <= 100 inches
--   * status is not 'Dead', 'Stump' or 'Planting Space'
--
-- ---------------------------------------------------------------------------
-- Part 1: average diameter by borough and census year
-- ---------------------------------------------------------------------------
-- The result has one row per borough and one column per census year, built
-- with conditional aggregation (AVG(IF(...))). change_1995_2015 is the
-- difference between the 2015 and the 1995 average, in inches.

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
  borough,
  COUNTIF(census_year = 1995) AS n_1995,
  COUNTIF(census_year = 2005) AS n_2005,
  COUNTIF(census_year = 2015) AS n_2015,
  ROUND(AVG(IF(census_year = 1995, dbh, NULL)), 2) AS avg_1995,
  ROUND(AVG(IF(census_year = 2005, dbh, NULL)), 2) AS avg_2005,
  ROUND(AVG(IF(census_year = 2015, dbh, NULL)), 2) AS avg_2015,
  ROUND(
    AVG(IF(census_year = 2015, dbh, NULL)) - AVG(IF(census_year = 1995, dbh, NULL)),
    2
  ) AS change_1995_2015
FROM clean_trees
GROUP BY borough
ORDER BY change_1995_2015 DESC;


-- ---------------------------------------------------------------------------
-- Part 2: the 15 most common species, with average diameter by census year
-- ---------------------------------------------------------------------------
-- Species names are not written the same way in every census:
--   * 1995 and 2005 use the format 'maple, norway'; 2015 uses 'norway maple'.
--   * Spelling also varies ('linden, little leaf' vs 'littleleaf linden').
--   * 2005 uses the placeholder 'unknown' for some trees.
-- Harmonisation rule:
--   1. lower-case and trim the name;
--   2. if it contains a comma, swap the words around it ('maple, norway'
--      becomes 'norway maple');
--   3. build a matching key by removing everything that is not a letter.
-- Trees with a missing or 'unknown' species are left out of this comparison.
-- Species named differently in other ways will not match across years and
-- therefore do not appear in the result.
-- HAVING keeps only species with at least 1,000 living trees in each census,
-- so that averages are not driven by a handful of trees.

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
),

lower_names AS (
  SELECT
    census_year,
    dbh,
    LOWER(TRIM(species)) AS species_lower
  FROM clean_trees
),

harmonised AS (
  SELECT
    census_year,
    dbh,
    CASE
      WHEN STRPOS(species_lower, ',') > 0 THEN CONCAT(
        TRIM(SUBSTR(species_lower, STRPOS(species_lower, ',') + 1)),
        ' ',
        TRIM(SUBSTR(species_lower, 1, STRPOS(species_lower, ',') - 1))
      )
      ELSE species_lower
    END AS species_display
  FROM lower_names
  WHERE species_lower IS NOT NULL
    AND species_lower != 'unknown'
),

keyed AS (
  SELECT
    census_year,
    dbh,
    species_display,
    REGEXP_REPLACE(species_display, r'[^a-z]', '') AS species_key
  FROM harmonised
)

SELECT
  MAX(species_display) AS species_name,
  COUNTIF(census_year = 1995) AS n_1995,
  COUNTIF(census_year = 2005) AS n_2005,
  COUNTIF(census_year = 2015) AS n_2015,
  ROUND(AVG(IF(census_year = 1995, dbh, NULL)), 2) AS avg_1995,
  ROUND(AVG(IF(census_year = 2005, dbh, NULL)), 2) AS avg_2005,
  ROUND(AVG(IF(census_year = 2015, dbh, NULL)), 2) AS avg_2015,
  ROUND(
    AVG(IF(census_year = 2015, dbh, NULL)) - AVG(IF(census_year = 1995, dbh, NULL)),
    2
  ) AS change_1995_2015
FROM keyed
GROUP BY species_key
HAVING COUNTIF(census_year = 1995) >= 1000
   AND COUNTIF(census_year = 2005) >= 1000
   AND COUNTIF(census_year = 2015) >= 1000
ORDER BY n_2015 DESC
LIMIT 15;
