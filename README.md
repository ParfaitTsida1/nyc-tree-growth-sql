# NYC Street Trees: Have They Grown Between 1995, 2005 and 2015?

A SQL project analysing three decades of New York City's Street Tree Census with Google BigQuery.

## Question

> Have New York City's street trees grown between 1995, 2005 and 2015, and where, and for which species?

## Data

- **Source:** NYC Street Tree Census, available in BigQuery's public datasets (`bigquery-public-data.new_york_trees`).
- **Tables used:** `tree_census_1995`, `tree_census_2005`, `tree_census_2015`.
- **Size:** 516,989 trees (1995), 592,372 trees (2005), 683,788 trees (2015).
- **Key measure:** trunk diameter at breast height (DBH), in inches. The column is named `diameter` in the 1995 table and `tree_dbh` in the 2005 and 2015 tables.

**Column mapping used to harmonise the three censuses**

| Concept | 1995 | 2005 | 2015 |
|---------|------|------|------|
| Diameter (inches) | `diameter` | `tree_dbh` | `tree_dbh` |
| Borough | `borough` | `boroname` | `boroname` |
| Species (common name) | `spc_common` | `spc_common` | `spc_common` |
| Species (Latin name) | `spc_latin` | `spc_latin` | `spc_latin` |
| Tree status | `status` | `status` | `status` |

## Tools and SQL skills

- Google BigQuery (sandbox, free tier)
- Exploration: `SELECT`, `COUNT`, `DISTINCT`, `LIMIT`
- Cleaning: `WHERE`, `NULL` handling, outlier detection, `CASE WHEN`
- Combining tables: `UNION ALL`, column aliases
- Aggregation: `GROUP BY`, `AVG`, median with `APPROX_QUANTILES`, `HAVING`, `ORDER BY`
- Readability: CTEs (`WITH`), comments
- Advanced: window functions (`RANK`, `LAG`)

## Repository structure

```
nyc-tree-growth-sql/
├── README.md
├── queries/
│   ├── 01_explore.sql
│   ├── 02_clean.sql
│   ├── 03_union_censuses.sql
│   ├── 04_average_by_year.sql
│   ├── 05_by_borough_species.sql
│   └── 06_species_rank_change.sql
└── results/
    ├── avg_diameter_by_year.png
    └── avg_diameter_by_borough.png
```

## Method

1. **Explore.** Counted rows and inspected the schema of each census table.
2. **Clean.** Profiled the diameter column (missing values, zeros, negative values, extreme values) and the `status` column, then defined cleaning rules.
3. **Harmonise.** Combined the three censuses into one table with consistent column names using `UNION ALL`.
4. **Compare by year.** Computed the average and median diameter for each census.
5. **Compare by borough and species.** Grouped results at several levels and filtered out small groups with `HAVING`.
6. **Go further.** Ranked species and measured change between censuses with window functions.

### Cleaning rules

**Raw profile of the diameter column**

| Census | Trees | NULL | Zero | Negative | Min | Max | Raw average |
|--------|------:|-----:|-----:|---------:|----:|----:|------------:|
| 1995 | 516,989 | 0 | 23,956 (4.6%) | 0 | 0 | 95 | 11.44 |
| 2005 | 592,372 | 0 | 1,542 (0.3%) | 1 | -1 | 2,100 | 12.83 |
| 2015 | 683,788 | 0 | 17,932 (2.6%) | 0 | 0 | 450 | 11.28 |

**Rules applied**

| Rule | Reason | Rows removed (1995 / 2005 / 2015) |
|------|--------|-----------------------------------|
| Remove `NULL` diameters | Cannot be measured | 0 / 0 / 0 |
| Remove diameters of 0 or less | Mostly not living trees: empty planting spaces, stumps and dead trees (see table below); one negative value in 2005 | 23,956 / 1,543 / 17,932 |
| Remove statuses `Dead`, `Stump`, `Planting Space` | Only living trees can grow, and many dead trees and stumps still have a positive diameter (for example 12,859 trees with status `Dead` in 1995, of which only 1,394 have a diameter of 0) | 14,508 / 7,056 / 13,902 (additional rows, after the diameter rules) |
| Remove diameters above 100 inches | Probable typing errors (values up to 2,100 in 2005 and 450 in 2015) | 0 / 89 / 70 |

> The 100-inch threshold is an analyst's choice. The largest 1995 value is 95, so nothing is removed that year. In 2005 and 2015 the largest values are almost all single trees, far beyond any realistic trunk size. The threshold removes very few rows (89 in 2005, 70 in 2015, under 0.02% of each census).

**Where the zero diameters come from (rows with a diameter of 0 or less, by status)**

| Census | Zero-diameter rows | Planting Space | Stump | Dead | Other statuses |
|--------|-------------------:|---------------:|------:|-----:|---------------:|
| 1995 | 23,956 | 15,231 | 3,044 | 1,394 | 4,287 |
| 2005 | 1,543 | 0 | 0 | 1,064 | 479 |
| 2015 | 17,932 | 0 | 17,654 | 56 | 222 |

Most zero diameters are not living trees: empty planting spaces in 1995 (64% of the zeros) and stumps in 2015 (98%). The status values are not the same in every census (see Limitations).

**Preliminary result of diameter-only cleaning (rule: 0 < diameter <= 100 inches, before any status filter)**

| Census | Trees before | Trees kept | Raw average | Clean average |
|--------|-------------:|-----------:|------------:|--------------:|
| 1995 | 516,989 | 493,033 | 11.44 | 12.00 |
| 2005 | 592,372 | 590,740 | 12.83 | 12.84 |
| 2015 | 683,788 | 665,786 | 11.28 | 11.57 |

**Final result of cleaning (diameter rule and status rule)**

| Census | Trees before | Trees kept | Share removed | Clean average |
|--------|-------------:|-----------:|--------------:|--------------:|
| 1995 | 516,989 | 478,525 | 7.4% | 12.06 |
| 2005 | 592,372 | 583,684 | 1.5% | 12.90 |
| 2015 | 683,788 | 651,884 | 4.7% | 11.70 |

**Distribution of diameters among cleaned trees (inches)**

| Census | Trees | Average | 25th percentile | Median | 75th percentile | Max |
|--------|------:|--------:|----------------:|-------:|----------------:|----:|
| 1995 | 478,525 | 12.06 | 5 | 10 | 17 | 95 |
| 2005 | 583,684 | 12.90 | 6 | 11 | 18 | 100 |
| 2015 | 651,884 | 11.70 | 5 | 10 | 16 | 100 |

The median and quartiles are approximate (`APPROX_QUANTILES`) and diameters are whole inches. The maximum of 100 in 2005 and 2015 is the cleaning cutoff.

**Trees above candidate thresholds**

| Census | > 50 in | > 100 in | > 150 in |
|--------|--------:|---------:|---------:|
| 1995 | 256 | 0 | 0 |
| 2005 | 1,921 | 89 | 14 |
| 2015 | 364 | 70 | 39 |

## Key findings

1. **Overall change.** After cleaning, the average trunk diameter went from 12.06 inches in 1995 to 12.90 in 2005 (+7.0%), then fell to 11.70 in 2015 (-9.3%). The 2015 average is 3.0% below the 1995 level.
2. **Cleaning matters.** Without cleaning, the 1995 average looks 0.62 inches lower (11.44 instead of 12.06) because 4.6% of its trees have a diameter of 0, and the 2015 average looks 0.42 inches lower (11.28 instead of 11.70). Cleaning removes 7.4% of the 1995 trees, 1.5% of the 2005 trees and 4.7% of the 2015 trees. Excluding dead trees, stumps and empty planting spaces changes each average by only 0.06 to 0.13 inches, so the trend does not depend on that rule.
3. **Median vs. average.** The median follows the same pattern as the average, with a smaller amplitude: 10 inches in 1995, 11 in 2005 and back to 10 in 2015. The average is about 2 inches above the median in every census, which means a few large trees pull it up (the distribution is skewed to the right). The 2015 median equals the 1995 median, while the 75th percentile is lower (16 inches against 17 in 1995 and 18 in 2005). The drop in the 2015 average therefore comes mostly from the upper end of the distribution, not from the typical tree.
4. **By borough.** Only Manhattan (+1.26 inches) and Staten Island (+0.83) have a larger average diameter in 2015 than in 1995, while the Bronx (-1.08), Brooklyn (-0.71) and Queens (-0.45) are lower. Every borough rose between 1995 and 2005 (+0.63 to +1.17 inches), so the decline happens between 2005 and 2015, and it is strongest in the Bronx (-2.03) and Brooklyn (-1.88). These two boroughs also gained the most trees between 1995 and 2015 (+77% and +57%, against +14% in Queens). This is consistent with new plantings pulling the average down, but the data do not prove it.
5. **By species.** Among the 15 most common species, 13 have a larger average diameter in 2015 than in 1995. The largest increases are green ash (+6.06 inches), callery pear (+3.57), honeylocust (+3.54) and silver maple (+3.14). Only northern red oak (-2.65) and American elm (-0.09) are lower. This contrasts with the overall average, which fell from 12.06 to 11.70 inches, so the decline does not seem to come from trees of the same species getting smaller. Most of this gain happened between 1995 and 2005 (+1.49 to +3.38 inches for each of the ten leading species of 2005). Between 2005 and 2015, six of the ten leading species of 2015 stayed within 0.33 inches of their 2005 average, and only honeylocust (+1.34) and callery pear (+1.77) kept growing.
6. **Species mix.** The mix of species changed a lot. Norway maple, the most common species in 1995 (106,506 trees), fell to 34,179 trees in 2015 (-68%), and London planetree (86,999 trees) is now the most common. Species with small average diameters grew fast: Japanese zelkova went from 5,602 to 29,251 trees, honeylocust from 33,169 to 64,251, and callery pear from 30,611 to 58,905 (after a peak of 63,357 in 2005). This shift toward small-diameter species is consistent with the fall of the overall average, but the 15 species cover only about 70% of the 2015 trees, so it is a lead rather than a full explanation.

![Line chart of the average and median trunk diameter of cleaned trees in 1995, 2005 and 2015](results/avg_diameter_by_year.png)

**Average diameter by borough (cleaned trees, inches)**

| Borough | Trees 1995 | Trees 2005 | Trees 2015 | Avg 1995 | Avg 2005 | Avg 2015 | Change 1995-2015 |
|---------|-----------:|-----------:|-----------:|---------:|---------:|---------:|-----------------:|
| Manhattan | 43,146 | 49,185 | 62,411 | 7.48 | 8.41 | 8.74 | +1.26 |
| Staten Island | 73,179 | 98,371 | 101,379 | 9.96 | 10.94 | 10.79 | +0.83 |
| Queens | 208,531 | 236,288 | 237,860 | 13.54 | 14.17 | 13.09 | -0.45 |
| Brooklyn | 108,232 | 141,177 | 169,683 | 12.85 | 14.02 | 12.14 | -0.71 |
| Bronx | 45,437 | 58,663 | 80,551 | 11.15 | 12.10 | 10.07 | -1.08 |

![Line chart of the average trunk diameter in each borough in 1995, 2005 and 2015](results/avg_diameter_by_borough.png)

**Average diameter of the 15 most common species (cleaned trees, inches)**

| Species | Trees 1995 | Trees 2005 | Trees 2015 | Avg 1995 | Avg 2005 | Avg 2015 | Change 1995-2015 |
|---------|-----------:|-----------:|-----------:|---------:|---------:|---------:|-----------------:|
| London planetree | 87,039 | 89,313 | 86,999 | 18.75 | 21.71 | 21.54 | +2.79 |
| Honeylocust | 33,169 | 52,032 | 64,251 | 6.66 | 8.86 | 10.20 | +3.54 |
| Callery pear | 30,611 | 63,357 | 58,905 | 5.36 | 7.16 | 8.93 | +3.57 |
| Pin oak | 36,073 | 43,761 | 53,173 | 14.04 | 17.18 | 16.85 | +2.81 |
| Norway maple | 106,506 | 73,924 | 34,179 | 12.68 | 14.62 | 14.31 | +1.64 |
| Littleleaf linden | 25,976 | 27,481 | 29,733 | 8.43 | 10.00 | 10.02 | +1.59 |
| Japanese zelkova | 5,602 | 14,544 | 29,251 | 5.60 | 7.81 | 7.85 | +2.25 |
| Ginkgo | 13,425 | 16,176 | 21,017 | 6.88 | 8.75 | 8.62 | +1.74 |
| Red maple | 17,652 | 20,132 | 17,244 | 10.11 | 11.60 | 10.67 | +0.57 |
| Green ash | 17,411 | 20,538 | 16,246 | 7.49 | 10.87 | 13.55 | +6.06 |
| Silver maple | 21,992 | 18,605 | 12,273 | 17.87 | 21.13 | 21.01 | +3.14 |
| Sweetgum | 6,557 | 8,359 | 10,653 | 9.27 | 12.01 | 11.08 | +1.81 |
| Northern red oak | 6,600 | 11,025 | 8,396 | 14.03 | 15.57 | 11.38 | -2.65 |
| American elm | 5,910 | 5,443 | 7,971 | 12.05 | 13.88 | 11.96 | -0.09 |
| Willow oak | 1,941 | 2,137 | 3,177 | 10.95 | 13.33 | 12.14 | +1.19 |

**Top 10 species by number of cleaned trees (trees in brackets)**

| Rank | 1995 | 2005 | 2015 |
|-----:|------|------|------|
| 1 | Norway maple (106,506) | London planetree (89,313) | London planetree (86,999) |
| 2 | London planetree (87,039) | Norway maple (73,924) | Honeylocust (64,251) |
| 3 | Pin oak (36,073) | Callery pear (63,357) | Callery pear (58,905) |
| 4 | Honeylocust (33,169) | Honeylocust (52,032) | Pin oak (53,173) |
| 5 | Callery pear (30,611) | Pin oak (43,761) | Norway maple (34,179) |
| 6 | Littleleaf linden (25,976) | Littleleaf linden (27,481) | Littleleaf linden (29,733) |
| 7 | Silver maple (21,992) | Green ash (20,538) | Cherry (29,256) |
| 8 | Red maple (17,652) | Red maple (20,132) | Japanese zelkova (29,251) |
| 9 | Green ash (17,411) | Silver maple (18,605) | Ginkgo (21,017) |
| 10 | Sugar maple (15,011) | Ginkgo (16,176) | Sophora (19,332) |

`Cherry` and `sophora` have no match in the earlier censuses under the name harmonisation rule, so their change since 2005 cannot be measured.

## Limitations

- The three censuses **do not follow the same trees**. The analysis compares populations, not the growth of individual trees.
- **Measurement methods may differ** between censuses, which can introduce inconsistencies.
- **Newly planted trees** have small diameters and pull the average down, which can hide the growth of older trees.
- The 1995 census contains a large share of zero diameters (4.6%), versus 0.3% in 2005, so the cleaning step has a different impact on each year.
- In 1995, some diameters appear unusually often (for example around 60 and 64 inches), which may reflect estimation or coding habits rather than real measurements.
- The 2005 census has many more large diameters (1,921 trees above 50 inches) than 1995 (256) or 2015 (364), which may reflect measurement or recording differences rather than real growth.
- The `status` column is not coded the same way in every census: 1995 mixes tree condition (`Excellent`, `Good`, `Fair`, `Poor`, `Critical`) with non-tree values (`Dead`, `Stump`, `Shaft`, `Planting Space`, `Unknown`), 2005 only has `Excellent`, `Good`, `Poor` and `Dead`, and 2015 only has `Alive`, `Dead` and `Stump`. Status can therefore only be used to exclude dead trees, stumps and empty planting spaces, not to compare tree condition across years.
- Borough coding is not identical across years: in 2005, 99,701 trees have the value `5` instead of a borough name. It matches borough code 5 (Staten Island), so it is recoded to "Staten Island" in `03_union_censuses.sql`.
- Species names are written differently across censuses: 1995 and 2005 use the format `maple, norway`, 2015 uses `norway maple`, and spelling varies (`linden, little leaf` against `littleleaf linden`). In 2005, 17,420 cleaned trees also have the species `unknown`. Names are harmonised in `05_by_borough_species.sql` with a simple rule (swap the words around the comma and ignore spaces), so species that are named differently in other ways may still not match across years and are left out of the species comparison.
- The 15 species in the species comparison cover about 70% of the cleaned 2015 trees (87% in 1995). Some very common 2015 names, such as `cherry` and `sophora`, do not appear in the comparison, probably because they are named differently in the earlier censuses, so the species analysis does not describe the whole tree population.
- The data are three snapshots (1995, 2005, 2015), so they say nothing about what happened between censuses.

## Conclusion

Between 1995 and 2005, New York's street trees got bigger: the cleaned average diameter rose from 12.06 to 12.90 inches, in every borough and for each of the ten most common species of 2005. Between 2005 and 2015 the average fell to 11.70 inches, below its 1995 level, while the median returned to 10 inches.

This fall does not come from trees shrinking: 13 of the 15 most common species have a larger average diameter in 2015 than in 1995. It is more consistent with a change in the mix of trees, with far fewer Norway maples and many more honeylocust, callery pear and Japanese zelkova trees, which have smaller diameters. The Bronx and Brooklyn, where the number of trees grew the most, show the largest declines.

These results compare populations, not individual trees, and the species analysis covers only about 70% of the 2015 trees. To measure real growth, the next step would be to follow the same trees across censuses (for example by matching their locations), to add tree age when available, and to check whether differences in measurement between censuses explain part of the 2005 peak.

## How to reproduce

1. Open the [BigQuery console](https://console.cloud.google.com/bigquery) and star the project `bigquery-public-data`.
2. Run the queries in `queries/` in numerical order.
3. Export the results to the `results/` folder.

## Author

Parfait Tsida - [GitHub: ParfaitTsida1](https://github.com/ParfaitTsida1)
