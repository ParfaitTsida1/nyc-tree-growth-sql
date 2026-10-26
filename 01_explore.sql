-- 01_explore.sql
-- Purpose: get to know the three NYC street tree census tables before analysing
--          them (size and structure).
-- Run each part separately: select its text, then click Run.

-- ---------------------------------------------------------------------------
-- Part 1: number of trees in each census
-- ---------------------------------------------------------------------------
SELECT '1995' AS census_year, COUNT(*) AS n_trees
FROM `bigquery-public-data.new_york_trees.tree_census_1995`
UNION ALL
SELECT '2005', COUNT(*)
FROM `bigquery-public-data.new_york_trees.tree_census_2005`
UNION ALL
SELECT '2015', COUNT(*)
FROM `bigquery-public-data.new_york_trees.tree_census_2015`;


-- ---------------------------------------------------------------------------
-- Part 2: columns of the three tables (name and type)
-- ---------------------------------------------------------------------------
-- Column names are not the same in every census (for example the diameter is
-- `diameter` in 1995 and `tree_dbh` in 2005 and 2015).
SELECT table_name, column_name, data_type
FROM `bigquery-public-data.new_york_trees.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name IN ('tree_census_1995', 'tree_census_2005', 'tree_census_2015')
ORDER BY table_name, ordinal_position;


-- ---------------------------------------------------------------------------
-- Part 3: only the columns needed for the analysis
-- ---------------------------------------------------------------------------
-- Borough, species, status and diameter columns in each table.
SELECT table_name, column_name, data_type
FROM `bigquery-public-data.new_york_trees.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name IN ('tree_census_1995', 'tree_census_2005', 'tree_census_2015')
  AND (
    LOWER(column_name) LIKE '%boro%'
    OR LOWER(column_name) LIKE '%spc%'
    OR LOWER(column_name) LIKE '%species%'
    OR LOWER(column_name) LIKE '%status%'
    OR LOWER(column_name) LIKE '%dbh%'
    OR LOWER(column_name) = 'diameter'
  )
ORDER BY table_name, column_name;
