/*
This script is my analytical findings from looking through the dataset and seeing what interesting results I could find across the different tables. Each query has an associated comment denoting what my goal 
with the query was and why I think that the result of the query is interesting.
*/

-- THESE ARE JUST SET-UP TABLES NEEDED FOR MULTIPLE OF THE QUERIES BELOW. RUN THESE FIRST BEFORE RUNNING ANY OF THE OTHER QUERIES :)
DROP TABLE IF EXISTS modern_points_system;
CREATE TABLE modern_points_system (
    position INT,
    modern_points INT
);

INSERT INTO modern_points_system (position, modern_points) VALUES
(1, 25),(2, 18),(3, 15),(4, 12),(5, 10),(6, 8),(7, 6),(8, 4),(9, 2),(10, 1);

DROP TABLE IF EXISTS points_for_fastest_lap;
CREATE TABLE points_for_fastest_lap (
    fastestlaprank INT,
    bonus_points INT
);

INSERT INTO points_for_fastest_lap (fastestlaprank, bonus_points) VALUES
(1, 1);

/*
POINTS PER YEAR AND POINTS PER RACE ADJUSTED FOR CHANGES IN POINT SCORING METHODOLOGY OVER TIME
This first finding is about which of the F1 drivers have scored the most points over their career. Specifically measured as points per year and points per race, to adjust for some drivers having longer careers
than others. Additionally the point scoring methodology has changed over time, meaning someone who completed a race in 2005, for instance, would have gotten less points for a given performance than they would
have for the same performance in a 2024 race.

The modern_point_system table contains the current point distributions for each of the top 10 placements in a race, which are the placements that currently get rewarded. These have been used to retroactively adjust
drivers' points score for races completed using older point scoring rules. Additionally, in modern races, the driver with the fastest lap overall get rewarded an additional point, which the points_for_fastest_lap
table is used to add. These additions mean that the resulting ranking of drivers is much closer to the true ranking, if the point scoring system had been consistent over time, but this also means that it deviates
quite significantly from the result that you would get from just aggregating points in the original dataset.

This query uses the following datasets as inputs:

    - Drivers: To pull in driver names
    - Races: To pull in information about the duration of drivers' careers, i.e. the first and last year that they participated in a race, according to the dataset. This lets me calculate the total number of years
    that they have participated in races for, again according to the dataset, and distribute their total point winnings across the years to calculate the avg. points per year metric
    - Results: Placements, fastest lap times, (adjusted) points awarded
    - Modern_points_system: My own dataset. Simply replaces the points awarded for a given placement in a race with modern point scoring rules, as explained above.
    - Points_for_fastest_lap: My own dataset. Used to award bonus points for fastest lap, as explained above.

Five common table expressions are used to combine the dataset and aggregate them into one. Specifically, the first three just aggregate data into a single table that the fourth CTE uses to calculate my chosen
performance metrics along with combining multiple tables again and the fifth is mainly used to format intervals for one and two degrees of standard deviation of points scored for a given driver.

Below this I create my table using a CTE chain with various steps and below that I have a selection of SELECT statements to highlight various findings that I find interesting in the table that I have created with  
explanations for why I find them interesting.  

In my second query I'm going to look into how teams pair up more or less volatile drivers. Do they go for a team of two highly volatile drivers or do they tend to pair a lower volatility driver with a higher 
volatility driver for a more balanced strategic approach?
*/

DROP TABLE IF EXISTS DriverPerformance;
CREATE TABLE DriverPerformance AS
WITH adjusted_results AS (
    SELECT r.raceid, r.driverid, r.points, r.position, r.fastestlaprank, COALESCE(mps.modern_points, 0) AS modern_points -- Coalesce used to handle cases that return NULL. In this case when a position does NOT reward any points.
    FROM results r
    LEFT JOIN modern_points_system mps ON r.position = mps.position
),
adjusted_results_with_bonus AS (
    SELECT ar.raceid, ar.driverid, ar.points, ar.position, ar.fastestlaprank, ar.modern_points, COALESCE(pffl.bonus_points, 0) as bonus_points -- Coalesce used to handle cases that return NULL. In this case for fastest lap time that don't reward points (only the #1 fastest lap per race gets awarded +1 points).
    FROM adjusted_results ar
    LEFT JOIN points_for_fastest_lap pffl ON ar.fastestlaprank = pffl.fastestlaprank
),
max_year AS (
    SELECT MAX(raceyear) as max_year FROM races
),
Career_points_table AS (
    SELECT
        d.driverref AS "Driver name",
        SUM(arwb.points) AS "Career points (legacy scoring)",
        SUM(arwb.modern_points) + sum(arwb.bonus_points) AS "Career points (modern scoring)",
        COUNT(DISTINCT arwb.raceid) AS "Races entered",
        ROUND(COUNT(DISTINCT arwb.raceid)::NUMERIC / COUNT(DISTINCT rc.raceyear), 2) AS "Races per year",
        ROUND(AVG(arwb.modern_points) + AVG(arwb.bonus_points), 2) AS "Avg. points per race",
        STDDEV(arwb.modern_points + arwb.bonus_points) AS "STDDEV",
        MIN(rc.raceyear) AS "First season",
        MAX(rc.raceyear) AS "Latest season",
        COUNT(DISTINCT rc.raceyear) AS "Years active in racing",
        ROUND((SUM(arwb.modern_points) + sum(arwb.bonus_points))::NUMERIC / COUNT(DISTINCT rc.raceyear), 2) AS "Avg. points per year active in racing",
        max_year.max_year - MAX(rc.raceyear) AS "Years since last active in a race",
        SUM(CASE WHEN arwb.position IS NULL THEN 1 ELSE 0 END) AS "Races with NULL finish",
        ROUND(SUM(CASE WHEN arwb.position IS NULL THEN 1 ELSE 0 END)::NUMERIC / COUNT(DISTINCT arwb.raceid) * 100, 2) AS "Percentage of races with NULL placement"
    FROM adjusted_results_with_bonus arwb
    INNER JOIN drivers d ON arwb.driverid = d.driverid
    INNER JOIN races rc ON arwb.raceid = rc.raceid
    CROSS JOIN max_year
    GROUP BY d.driverref, max_year.max_year
    HAVING (SUM(arwb.modern_points) + sum(arwb.bonus_points)) >= 1000
),
Final_output_table AS (
    SELECT
        cpt."Driver name",
        cpt."Career points (legacy scoring)",
        cpt."Career points (modern scoring)",
        cpt."Races entered",
        cpt."Races per year",
        cpt."Avg. points per race",
        ROUND(cpt."STDDEV", 2) AS "Standard deviation (~volatility)",

        CONCAT(
            '[', 
            GREATEST(0.00, ROUND(cpt."Avg. points per race" - cpt."STDDEV", 2)), 
            ' - ', 
            LEAST(25, ROUND(cpt."Avg. points per race" + cpt."STDDEV", 2)), 
            ']'
        ) AS "1 standard deviation for scored points",

        CONCAT(
            '[', 
            GREATEST(0.00, ROUND(cpt."Avg. points per race" - 2 * cpt."STDDEV", 2)), 
            ' - ', 
            LEAST(25, ROUND(cpt."Avg. points per race" + 2 * cpt."STDDEV", 2)), 
            ']'
        ) AS "2 standard deviation for scored points",

        cpt."First season",
        cpt."Latest season",
        cpt."Years active in racing",
        cpt."Avg. points per year active in racing",
        cpt."Years since last active in a race",
        cpt."Races with NULL finish",
        cpt."Percentage of races with NULL placement",
        1 AS "Sort by order"
    FROM Career_points_table cpt
),
Unioned_table AS (
    SELECT * FROM Final_output_table
    UNION ALL
    SELECT
        'Subtotals row (averages)',
        ROUND(AVG("Career points (legacy scoring)"), 0),
        ROUND(AVG("Career points (modern scoring)"), 0),
        ROUND(AVG("Races entered"), 0),
        ROUND(AVG("Races per year"), 2),
        ROUND(AVG("Avg. points per race"), 2),
        ROUND(AVG("Standard deviation (~volatility)"), 2),
        NULL,
        NULL,
        NULL,
        NULL,
        ROUND(AVG("Years active in racing"), 0),
        ROUND(AVG("Avg. points per year active in racing"), 2),
        ROUND(AVG("Years since last active in a race"), 0),
        ROUND(AVG("Races with NULL finish"), 0),
        ROUND(AVG("Percentage of races with NULL placement"), 2),
        2
    FROM Final_output_table
)
SELECT * FROM Unioned_table;

SELECT * FROM DriverPerformance
/*This SELECT statement is just there in case you want to see the entire output table from the above CTE chain. The SELECT statements below are my curated highlights with comments about what I find interesting.*/

SELECT "Driver name", "Career points (legacy scoring)", "Career points (modern scoring)", "Races entered", "Years active in racing" FROM DriverPerformance ORDER BY "Sort by order" ASC, "Career points (modern scoring)" DESC
/*First, let me define the two "Career points" columns in this table. The legacy scoring column uses the point distribution model from the year that a given race was driven, while the modern scoring column uses the most  
recent scoring model for formula 1 races. This means that the legacy column shows how many points a driver actually earned in their career, but the modern column shows how many points they would have earned, if the  
scoring methodology had been consistent over the years. And the difference really shows in the totals. Looking at Michael Schumacer, for instance, based on the legacy scoring models, his total career points comes nowhere  
close to the other top 5 drivers sorted by modern points, but when the points per race are adjusted to use the modern scoring system, he's the 2nd best driver based on total career points. Another noteworthy thing is  
Max Verstappen. He's been driving for 10 years total (within the timeline of this dataset which isn't fully up-to-date) and yet he's the driver with the 5th most points, scoring close to drivers like Alonso, Vettel and  
Scumacher, but with 6-11 years less of driving. If he keeps up that pace, he's likely going to be the number 1 or 2 driver in terms of career points, depending on how Hamilton continues to perform.*/

SELECT "Driver name", "Avg. points per year active in racing", "Avg. points per race" FROM DriverPerformance ORDER BY "Sort by order" ASC, "Avg. points per year active in racing" DESC, "Avg. points per race" DESC
/*Sorting by average points per year and average points per race gives a more detailed view of drivers' performance. Verstappen and Hamilton outperform the other drivers by a significant amount when sorting the
data this way. But the more interesting finding is the implications on consistency over time. Notice how the top 7 drivers in terms of points per year almost all have double digit average scores for points per
race, with the one exception being Leclerc. Leclerc has an average of 9 points per race, which suggests to me that while he is a really strong driver, his performance in any given race is less consistent than
most of the other top drivers. And yet he manages to get a top 5 placement, indicating that when he performs well in a race, he really, really performs well.*/

SELECT "Driver name", "Avg. points per year active in racing", "Avg. points per race", "Years active in racing", "Races per year", "Percentage of races with NULL placement" FROM DriverPerformance ORDER BY "Sort by order" ASC, "Avg. points per year active in racing" DESC, "Percentage of races with NULL placement" DESC
/*Interestingly Leclerc does not have a particularly high non-finish percentage, at just 15.44%, so that does not explain the variance. I've categorized non-finish races as races where the placement variable is NULL
suggesting the driver did not finish the race. He does have a significantly higher number of races entered per year at 21.29 compared to essentially all other drivers. With the exception of Max Verstappen, all other  
top drivers in this view have entered less than 20 races per year on average. So Leclerc might not actually be amongst the very best drivers, but entering more races per year, pushes his total average points per year  
up to match some of the very best drivers in the sport.*/  

SELECT "Driver name", "Percentage of races with NULL placement" FROM DriverPerformance ORDER BY "Sort by order" ASC, "Percentage of races with NULL placement" ASC
/*Vettel is by far the driver with the lowest non-finish percentage, with just 8.43% of his races resulting in a NULL position, again, suggesting he did not finish the race. Most all other drivers have double digit  
non-finish percentages, with the average across all included drivers (drivers with >1,000 career points) being 27.65%, but that's heavily influenced by the bottom 10-15 drivers.*/  

SELECT "Driver name", "Latest season", "Avg. points per race" FROM DriverPerformance ORDER BY "Sort by order" ASC, "Avg. points per race" DESC, "Latest season" DESC
/*Only 7 out of the 31 drivers with a total of 1,000 or more points in their career have double digit average points per race, with Hamilton and Verstappen being the two drivers with the highest average points
per race out of all of them. The double digit average points per race drivers seem to be fairly spread out over time tho. Sorting by the drivers' latest active season spread out the double digit average points 
per race drivers fairly well, with Hamilton and Verstappen being the current double digit drivers, and Senna, Prost & Stewart being double digit drivers from 30-50 years ago. Of course, Schumacher is also in the  
top 3 drivers from this perspective, with his latest active season being in 2012.*/  

SELECT "Driver name", "Career points (modern scoring)", "Standard deviation (~volatility)" FROM DriverPerformance ORDER BY "Sort by order" ASC, "Standard deviation (~volatility)" ASC
/*Interestingly, sorting drivers by volatility shows that the volatility (standard deviation) of drivers ranges from about 6 to about 10.5, with no high scoring drivers, in terms of aggregated career points,
having a lower standard deviation than about 8. This suggests that the higher performing drivers, across the board, are some of the more volatile ones, which would makes sense under the assumption that you likely
have to take risks in a race, if you want to hit a podium finish. Though, be aware that the variance in points scored between high placements and low placements is quite high. In other words, the difference
in points awarded between someone getting a 1st and 2nd place finish is 7 points, while the difference between someone getting a 9th and 10th place finish is just 1 point. This means that someone who fluctuates
between, say, the top 5 placements most of the time, is going to have a higher variation in points scored per race, than someone who fluctuates between the 6th and 10th position placement.
It is interesting to see Hamilton have an impressively low standard deviation of 8.88 relative to the other top drivers like Vettel (9.14) and Verstappen (9.47).*/  

/*The following query uses the Gaps & Islands methodology to combine driver pairs into stints, with a stint being defined as a continuous streak of races by the same pair of drivers for the same team.  
Then metrics such as the change in drivers' volatility (std. dev. for points scored), drivers volatility rating (high / medium / low volatility) and teams' choices for the combination of high,  
medium and low volatility drivers for their team is calculated. Similar to the above query, I have included a few queries below the following CTE chain that highlight a few findings that I find  
interesting from the resulting output table, but my chosen highlight aren't exhaustive of all interesting findings in the output table, given how many perspectives you can take on the data to find  
an interesting finding.*/

DROP TABLE IF EXISTS TeamStrategy;
CREATE TABLE TeamStrategy AS
WITH adjusted_results AS (
    SELECT r.raceid, r.driverid, r.constructorid, r.position, r.fastestlaprank, COALESCE(mps.modern_points, 0) AS modern_points -- Coalesce used to handle cases that return NULL. In this case when a position does NOT reward any points.
    FROM results r
    LEFT JOIN modern_points_system mps ON r.position = mps.position
),
adjusted_results_with_bonus AS (
    SELECT 
        d.driverref AS "Driver name",
        c.constructorname AS "Team name",
        ar.raceid AS "Race ID", 
        ar.driverid AS "Driver ID", 
        ar.position AS "Position", 
        ar.fastestlaprank, 
        ar.modern_points, 
        COALESCE(pffl.bonus_points, 0) AS bonus_points -- Coalesce used to handle cases that return NULL. In this case for fastest lap time that don't reward points (only the #1 fastest lap per race gets awarded +1 points).
    FROM adjusted_results ar
    LEFT JOIN points_for_fastest_lap pffl ON ar.fastestlaprank = pffl.fastestlaprank
    INNER JOIN drivers d ON ar.driverid = d.driverid
    INNER JOIN constructors c on ar.constructorid = c.constructorid
),
base_table AS (
    SELECT
        arwb."Team name",
        arwb."Driver name",
        arwb."Race ID",
        arwb.modern_points + arwb.bonus_points AS "Points"
    FROM adjusted_results_with_bonus arwb
),
pairs_table AS (
    SELECT
        b1."Team name" AS "Team name",
        b1."Driver name" AS "Driver #1 name",
        b1."Points" AS "Driver #1 points",
        ROUND(STDDEV(b1."Points") OVER (PARTITION BY b1."Driver name" ORDER BY b1."Race ID" ASC), 2) AS "Driver #1 rolling STDDEV",
        b2."Driver name" AS "Driver #2 name",
        b2."Points" AS "Driver #2 points",
        ROUND(STDDEV(b2."Points") OVER (PARTITION BY b2."Driver name" ORDER BY b2."Race ID" ASC), 2) AS "Driver #2 rolling STDDEV",
        b1."Race ID" AS "Race ID",
        DENSE_RANK() OVER (ORDER BY b1."Race ID" ASC) AS "G&L main index",
        DENSE_RANK() OVER (PARTITION BY b1."Team name", b1."Driver name", b2."Driver name" ORDER BY b1."Race ID" ASC) AS "G&L specific index"
    FROM base_table b1
    INNER JOIN base_table b2
        ON b1."Team name" = b2."Team name"
        AND b1."Race ID" = b2."Race ID"
        AND b1."Driver name" < b2."Driver name"
),
percentile_metrics AS (
    SELECT
        GREATEST(MAX(ABS(pt."Driver #1 rolling STDDEV")), MAX(ABS(pt."Driver #2 rolling STDDEV"))) AS "Rolling STDDEV max value",
        LEAST(MIN(ABS(pt."Driver #1 rolling STDDEV")), MIN(ABS(pt."Driver #2 rolling STDDEV"))) AS "Rolling STDDEV min value",
        GREATEST(MAX(ABS(pt."Driver #1 rolling STDDEV")), MAX(ABS(pt."Driver #2 rolling STDDEV")))
        -
        LEAST(MIN(ABS(pt."Driver #1 rolling STDDEV")), MIN(ABS(pt."Driver #2 rolling STDDEV")))
        AS "Rolling STDDEV width"
    FROM pairs_table pt
),
Gaps_and_islands_table AS (
    SELECT
        pt."Team name",
        pt."Driver #1 name",
        pt."Driver #1 points",
        pt."Driver #1 rolling STDDEV",
        pt."Driver #2 name",
        pt."Driver #2 points",
        pt."Driver #2 rolling STDDEV",
        pm."Rolling STDDEV max value" AS "Rolling STDDEV max value",
        pm."Rolling STDDEV min value" AS "Rolling STDDEV min value",
        pm."Rolling STDDEV width" AS "Rolling STDDEV width",
        pt."Race ID",
        pt."G&L main index",
        pt."G&L specific index",
        pt."G&L main index" - pt."G&L specific index" AS "G&L distance measure"
    FROM pairs_table pt
    CROSS JOIN percentile_metrics pm
),
final_output_table AS (
    SELECT
        git."Team name",
        git."Driver #1 name",
        git."Driver #1 points",
        git."Driver #1 rolling STDDEV",
        git."Driver #2 name",
        git."Driver #2 points",
        git."Driver #2 rolling STDDEV",
        git."Rolling STDDEV width" * 0.33 + git."Rolling STDDEV min value" AS "33th percentile",
        git."Rolling STDDEV width" * 0.66 + git."Rolling STDDEV min value" AS "66th percentile",
        git."Race ID",
        git."G&L distance measure",
        COUNT(*) OVER (PARTITION BY git."Team name", git."Driver #1 name", git."Driver #2 name", git."G&L distance measure") AS "Team/Drivers combo race counter"
    FROM Gaps_and_islands_table git
),
final_output_table_filtered AS (
    SELECT
        fot."Team name",
        fot."Driver #1 name",
        fot."Driver #1 points",
        fot."Driver #1 rolling STDDEV",

        CASE 
        WHEN FIRST_VALUE(fot."Driver #1 rolling STDDEV") OVER stint_window_driver_1 IS NULL
        THEN LAST_VALUE(fot."Driver #1 rolling STDDEV") OVER stint_window_driver_1 - NTH_VALUE(fot."Driver #1 rolling STDDEV", 2) OVER stint_window_driver_1
        ELSE LAST_VALUE(fot."Driver #1 rolling STDDEV") OVER stint_window_driver_1 - FIRST_VALUE(fot."Driver #1 rolling STDDEV") OVER stint_window_driver_1
        END AS "Driver #1 stint volatility trend",

        CASE 
        WHEN fot."Driver #1 rolling STDDEV" <= fot."33th percentile" THEN 'Low volatility'
        WHEN fot."Driver #1 rolling STDDEV" <= fot."66th percentile" THEN 'Medium volatility'
        ELSE 'High volatility'
        END AS "Driver #1 volatility class",

        fot."Driver #2 name",
        fot."Driver #2 points",
        fot."Driver #2 rolling STDDEV",

        CASE 
        WHEN FIRST_VALUE(fot."Driver #2 rolling STDDEV") OVER stint_window_driver_2 IS NULL
        THEN LAST_VALUE(fot."Driver #2 rolling STDDEV") OVER stint_window_driver_2 - NTH_VALUE(fot."Driver #2 rolling STDDEV", 2) OVER stint_window_driver_2
        ELSE LAST_VALUE(fot."Driver #2 rolling STDDEV") OVER stint_window_driver_2 - FIRST_VALUE(fot."Driver #2 rolling STDDEV") OVER stint_window_driver_2
        END AS "Driver #2 stint volatility trend",

        CASE 
        WHEN fot."Driver #2 rolling STDDEV" <= fot."33th percentile" THEN 'Low volatility'
        WHEN fot."Driver #2 rolling STDDEV" <= fot."66th percentile" THEN 'Medium volatility'
        ELSE 'High volatility'
        END AS "Driver #2 volatility class",

        ABS(fot."Driver #1 rolling STDDEV" - fot."Driver #2 rolling STDDEV") AS "ABS difference between driver STDDEVs",
        fot."Race ID",
        rc.raceyear as "Year",
        fot."G&L distance measure",
        fot."Team/Drivers combo race counter"
    FROM final_output_table fot
    LEFT JOIN races rc ON fot."Race ID" = rc.raceid
    WHERE fot."Team/Drivers combo race counter" >= 10 AND fot."Driver #1 rolling STDDEV" IS NOT NULL AND fot."Driver #2 rolling STDDEV" IS NOT NULL
    WINDOW 
        stint_window_driver_1 AS (
            PARTITION BY fot."Driver #1 name", fot."G&L distance measure"
            ORDER BY fot."Race ID" ASC
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ),
        stint_window_driver_2 AS (
            PARTITION BY fot."Driver #2 name", fot."G&L distance measure"
            ORDER BY fot."Race ID" ASC
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        )
),
team_strategy_classification AS (
    SELECT
        fotf."Team name",

        CASE
        WHEN fotf."Driver #1 rolling STDDEV" < fotf."Driver #2 rolling STDDEV"
        THEN CONCAT(
            fotf."Driver #1 volatility class",
            ' / ',
            fotf."Driver #2 volatility class",
            ' driver pair'
        ) 
        ELSE CONCAT(
            fotf."Driver #2 volatility class",
            ' / ',
            fotf."Driver #1 volatility class",
            ' driver pair'
        ) 
        END AS "Team driver pairing strategy",
        
        fotf."Driver #1 name",
        fotf."Driver #1 points",
        fotf."Driver #1 rolling STDDEV",
        fotf."Driver #1 stint volatility trend",
        fotf."Driver #1 volatility class",
        fotf."Driver #2 name",
        fotf."Driver #2 points",
        fotf."Driver #2 rolling STDDEV",
        fotf."Driver #2 stint volatility trend",
        fotf."Driver #2 volatility class",
        fotf."ABS difference between driver STDDEVs",
        fotf."Race ID",
        fotf."Year",
        fotf."G&L distance measure",
        fotf."Team/Drivers combo race counter"
    FROM final_output_table_filtered fotf
)
SELECT * FROM team_strategy_classification;

DROP TABLE IF EXISTS TeamStrategyAggregated;
CREATE TABLE TeamStrategyAggregated AS
WITH grouped_results_for_stints AS (
    SELECT
        tsc."Year",
        tsc."Team name",
        tsc."Team driver pairing strategy",
        tsc."Driver #1 name",
        ROUND(ABS(AVG(tsc."Driver #1 stint volatility trend")), 2) AS "ABS driver #1 stint volatility trend",
        tsc."Driver #2 name",
        ROUND(ABS(AVG(tsc."Driver #2 stint volatility trend")), 2) AS "ABS driver #2 stint volatility trend",
        AVG(tsc."Team/Drivers combo race counter")::INTEGER AS "Team/Drivers combo race counter"
    FROM TeamStrategy tsc
    GROUP BY tsc."Year", tsc."Team driver pairing strategy", tsc."Driver #1 name", tsc."Driver #2 name", tsc."Team name"
)

SELECT * FROM TeamStrategy
/*This SELECT statement is just there in case you want to see the entire unaggregated output table from the above CTE chain.*/

SELECT * FROM TeamStrategyAggregated
/*This SELECT statement is just there in case you want to see the entire aggregated output table from the above CTE chain. The SELECT statements below are my curated highlights with comments about what I find interesting.*/

CREATE TABLE FerrariSummary AS
SELECT 
    "Team name",
    "Driver #1 name",
    ROUND(AVG("ABS driver #1 stint volatility trend"), 2) AS "Driver #1 stint volatility trend",
    "Driver #2 name",
    ROUND(AVG("ABS driver #2 stint volatility trend"), 2) AS "Driver #2 stint volatility trend",
    ROUND(AVG("Team/Drivers combo race counter"), 2) AS "Team/Drivers combo race counter"
FROM TeamStrategyAggregated 
WHERE "Team name"='Ferrari' 
GROUP BY
    "Team name",
    "Driver #1 name",
    "Driver #2 name";

SELECT
    *
FROM FerrariSummary
ORDER BY
    "Team/Drivers combo race counter" DESC;
/*Looking at Ferrari specifically there are some interesting findings. The combo of Barrichello and Michael Schumacher is Ferrari's longest lasting driver pair, with 104 races total together.  
The other most noteworthy pair in terms of the number of races together, is Raikkonen and Vettel with 81 races together for Ferrari. After that the gap in the duration of the stint of  
each pair of drivers becomes much shorter. Do note, however, that both Michael Schumacher and Raikkonen have been in multiple driver pairs for Ferrari, meaning their individual stints for the  
team is significantly longer.*/

SELECT
    "Team name",
    'Michael Schumacher' AS "Driver name",
    SUM("Team/Drivers combo race counter") AS "Total races driven for Ferrari"
FROM FerrariSummary
WHERE "Driver #1 name"='michael_schumacher' OR "Driver #2 name"='michael_schumacher'
GROUP BY
    "Team name";
/*Summarizing all of the races that Michael Schumacher has done with various partners on the Ferrari team, shows he's driven a total of 173 races for Ferrari.*/

DROP TABLE IF EXISTS MichaelSchumacherSummary;
CREATE TABLE MichaelSchumacherSummary AS
SELECT
    "Year",
    "Team name",
    "Driver #1 name",
    "Driver #2 name",
    "Team/Drivers combo race counter"
FROM TeamStrategyAggregated
WHERE "Driver #1 name"='michael_schumacher' OR "Driver #2 name"='michael_schumacher'
ORDER BY
    "Year" DESC;
SELECT * FROM MichaelSchumacherSummary;
/*Going a step further an looking at Michael Schumacher's broader career, shows that he drove for Benetton before driving for Ferrari and drove for Mercedes after driving for Ferrari.*/  

WITH MS_TeamSummary AS (
    SELECT
        "Team name",
        "Driver #1 name",
        "Driver #2 name",
        ROUND(AVG("Team/Drivers combo race counter"), 2) AS "Team/Drivers combo race counter"
    FROM MichaelSchumacherSummary
    GROUP BY
        "Team name",
        "Driver #1 name",
        "Driver #2 name",
        "Team/Drivers combo race counter"
),
MS_TotalRacesPerTeam AS (
    SELECT
        "Team name",
        ROUND(SUM("Team/Drivers combo race counter"), 0) AS "Total races for team"
    FROM MS_TeamSummary
    GROUP BY
        "Team name"
),
MS_UnionedTable AS (
    SELECT * FROM MS_TotalRacesPerTeam
    UNION ALL
    SELECT
        'Total across all teams',
        ROUND(SUM("Total races for team"), 0)
    FROM MS_TotalRacesPerTeam
)

SELECT * FROM MS_UnionedTable;
/*In total Michael Schumacher has completed 280 races within the time cutoff of this dataset, with 173 races being for Ferrari, 49 being for Benetton and 58 being for Mercedes.*/  

/*Appendix: Use the following to get an overview of my database's tables:*/
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public';