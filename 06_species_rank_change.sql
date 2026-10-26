-- 06_species_rank_change.sql
-- Purpose: rank species by number of living trees in each census and measure how
--          rank, tree count and average diameter changed since the previous
--          census, using window functions (RANK and LAG).
--
-- Cleaning rules (see 03_union_censuses.sql):
--   * 0 < dbh <= 100 inches
--   * status is not 'Dead', 'Stump' or 'Planting Space'
--
-- Species names are harmonised as in 05_by_borough_species.sql (part 2):
-- swap the words around a comma, ignore spaces, drop 'unknown' and missing names.
--
-- How to read the result:
--   * rank_by_count: rank of the species in that census (1 = most trees).
--   * previous_rank, change_in_trees, change_in_avg_dbh: compared with the
--     previous census (1995 for 2005, 2005 for 2015). They are NULL for 1995
--     and for species that have no match in the previous census.
--   * Filtering on rank happens at the end, so the previous-census values are
--     still available for species that were ranked lower before.

WITH all_trees AS (
  SELECT
    1995 AS census_year,
    spc_common AS species,
    status,
    diameter AS dbh
  FROM `bigquery-public-data.new_york_trees.tree_census_1995`

  UNION ALL

  SELECT
    2005,
    spc_common,
    status,
    tree_dbh
  FROM `bigquery-public-data.new_york_trees.tree_census_2005`

  UNION ALL

  SELECT
    2015,
    spc_common,
    status,
    tree_dbh
  FROM `bigquery-public-data.new_york_trees.tree_census_2015`
),

clean_trees AS (
  SELECT census_year, species, dbh
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

species_counts AS (
  SELECT
    census_year,
    REGEXP_REPLACE(species_display, r'[^a-z]', '') AS species_key,
    MAX(species_display) AS species_name,
    COUNT(*) AS n_trees,
    ROUND(AVG(dbh), 2) AS avg_dbh
  FROM harmonised
  GROUP BY census_year, species_key
),

ranked AS (
  SELECT
    *,
    RANK() OVER (PARTITION BY census_year ORDER BY n_trees DESC) AS rank_by_count
  FROM species_counts
),

with_previous AS (
  SELECT
    census_year,
    species_name,
    n_trees,
    avg_dbh,
    rank_by_count,
    LAG(rank_by_count) OVER census_order AS previous_rank,
    LAG(n_trees) OVER census_order AS previous_n_trees,
    LAG(avg_dbh) OVER census_order AS previous_avg_dbh
  FROM ranked
  WINDOW census_order AS (PARTITION BY species_key ORDER BY census_year)
)

SELECT
  census_year,
  rank_by_count,
  species_name,
  n_trees,
  previous_rank,
  n_trees - previous_n_trees AS change_in_trees,
  avg_dbh,
  ROUND(avg_dbh - previous_avg_dbh, 2) AS change_in_avg_dbh
FROM with_previous
WHERE rank_by_count <= 10
ORDER BY census_year, rank_by_count;
