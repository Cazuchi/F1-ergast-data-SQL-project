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
    - Races: To pull in information about the duration of drivers' careers, i.e. the first and last year that they participated in a race, according to the dataset. Which lets me calculate the total number of years
    that they have participated in races for, again according to the dataset, and distribute their total point winnings across the years to calculate the avg. points per year metric
    - Results: Placements, fastest lap times, (adjusted) points awarded
    - Modern_points_system: My own dataset. Simply replaces the points awarded for a given placement in a race with modern point scoring rules, as explained above.
    - Points_for_fastest_lap: My own dataset. Used to award bonus points for fastest lap, as explained above.

Three common table expressions are used to combine the dataset and aggregate them into one. Specifically, the first two just aggregated data into single tables that the third then uses to calculate my chosen
performance metrics along with combining multiple tables again.

At the bottom I've included multiple order by statements, meant to be used one at a time, which is why all but one are commented out. There are multiple interesting findings in the table resulting from this query,
which are most easily seen by sorting the table in different ways. Here are the main findings that I would like to highlight from each order by statement:

    - ORDER BY "Sort by order" ASC, "Career points" DESC
    Just a simple sort by total points scored over their career. Nothing too surprising, but interesting that drivers like Max Verstappen, Vettel and Hamilton have close to or more points, than drivers like
    Michael Schumacher and Alonso, who have spent many more years racing than these younger drivers. Apparently there has been an increase in the number of races per year over time in F1 racing tho, so that 
    is likely part of the explanation for the aggregated points totals between drivers from different eras. Michael Schumacher is still especially interesting tho', because the non-adjusted points aggregates places
    him much, much further down the leaderboard, with less than 2,000 points over his career. This is simply due to the fact that the general trend in point scoring has gone up quite dramatically over time, 
    but it's interesting non the less how much the interpretation of a driver's performance changes significantly when the points aggregates are adjusted to have even scoring methodologies over time. 
    In this view, based on aggregate points scored and years racing, Max Verstappen, Senna, Bottas and Rosberg seem like incredibly strong performers, although only two of them seem to still be active drivers, 
    with record from 2024.

    - ORDER BY "Sort by order" ASC, "Avg. points per year active in racing" DESC, "Avg. points per race" DESC;
    Sorting by average points per year and average points per race gives a more detailed view of drivers' performance. Verstappen and Hamilton outperform the other drivers by a significant amount when sorting the
    data this way. But the more interesting finding is the implications on consistency over time. Notice how the top 7 drivers in terms of points per year almost all have double digit average scores for point per
    race, with the one exception being Leclerc. Leclerc has an average of 9 points per race, which suggests to me that while he is a really strong driver, his performance in any given race is less consistent than
    most of the other top drivers. And yet he manages to get a top 3 placement, indicating that when he performs well in a race, he really, really performs well.

    - ORDER BY "Sort by order" ASC, "Avg. points per year active in racing" DESC, "Races with NULL finish" DESC
    Interestingly Leclerc does not have a particularly high non-finish percentage, at just 15.44%, so that does not explain the variance. I've categorized non-finish races as races where the placement variable is NULL suggesting the driver did not
    finish the race. He does have a wide range of point scores across his 149 registered races tho, which could simply be the explanation for the lower average score per race.

    - ORDER BY "Sort by order" ASC, "Percentage of races with NULL placement" ASC
    Vettel is by far the driver with the lowest non-finish percentage, with just 8.43% of his races resulting in a NULL position, again suggesting he did not finish the race.

    - ORDER BY "Sort by order" ASC, "Latest season" DESC, "Avg. points per race" DESC
    Only 7 out of the 31 drivers with a total of 1,000 or more points in their career have double digit average points per race, with Hamilton and Verstappen being the two drivers with the highest average points
    per race out of all of them. The double digit average points per race drivers seem to be fairly spread out over time tho. Sorting by number of years since the drivers' last race participations spread out the
    double digit average points per race drivers fairly well, with Hamilton and Verstappen being the current double digit drivers, and Senna, Prost & Stewart being double digit drivers from 30-50 years ago.

    - ORDER BY "Sort by order" ASC, "Standard deviation (~volatility)" ASC
    Interestingly, sorting drivers by volatility shows that the volatility (standard deviation) of drivers ranges from about 6 to about 10.5, with no high scoring drivers, in terms of aggregated career points,
    having a lower standard deviation than 8. This suggests that the higher performing drivers, across the board, are some of the more volatile ones, which would makes sense under the assumption that you likely
    have to take risks in a race, if you want to hit a podium finish. In a later query I'm going to look into how teams pair up more or less volatile drivers. Do they go for a team of two highly volatile drivers
    or do they tend to pair a lower volatility driver with a higher volatility driver for a more balanced strategic approach?
*/

WITH adjusted_results AS (
    SELECT r.raceid, r.driverid, r.position, r.fastestlaprank, COALESCE(mps.modern_points, 0) AS modern_points -- Coalesce used to handle cases that return NULL. In this case when a position does NOT reward any points.
    FROM results r
    LEFT JOIN modern_points_system mps ON r.position = mps.position
),
adjusted_results_with_bonus AS (
    SELECT ar.raceid, ar.driverid, ar.position, ar.fastestlaprank, ar.modern_points, COALESCE(pffl.bonus_points, 0) as bonus_points -- Coalesce used to handle cases that return NULL. In this case for fastest lap time that don't reward points (only the #1 fastest lap per race gets awarded +1 points).
    FROM adjusted_results ar
    LEFT JOIN points_for_fastest_lap pffl ON ar.fastestlaprank = pffl.fastestlaprank
),
max_year AS (
    SELECT MAX(raceyear) as max_year FROM races
),
Career_points_table AS (
    SELECT
        d.driverref AS "Driver name",
        SUM(arwb.modern_points) + sum(arwb.bonus_points) AS "Career points",
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
        cpt."Career points",
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
)

SELECT * FROM Final_output_table
UNION ALL
SELECT
    'Subtotals row (averages)',
    ROUND(AVG("Career points"), 0),
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
-- ORDER BY "Sort by order" ASC, "Career points" DESC
-- ORDER BY "Sort by order" ASC, "Avg. points per year active in racing" DESC, "Avg. points per race" DESC
-- ORDER BY "Sort by order" ASC, "Avg. points per year active in racing" DESC, "Races with NULL finish" DESC
-- ORDER BY "Sort by order" ASC, "Percentage of races with NULL placement" ASC
-- ORDER BY "Sort by order" ASC, "Latest season" DESC, "Avg. points per race" DESC
ORDER BY "Sort by order" ASC, "Standard deviation (~volatility)" ASC

/*
QUERY SHOWING POINT AGGREGATION PER YEAR PER DRIVER. Is it linear? Do they tend to follow the same trend? High volatility vs. lower volatility drivers
*/

/*
TABLE SHOWING TEAM'S STRATEGIC CHOICES IN TEAMS OF PAIRING DRIVERS OF DIFFERENT VOLATILITY LEVELS. Does there seem to be a consistent strategy amongst teams? Are some teams outliers in terms of their choice of
paired drivers?
*/

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
        COUNT(*) OVER (PARTITION BY b1."Team name", b1."Driver name", b2."Driver name") AS "Team/Drivers combo race counter"
    FROM base_table b1
    INNER JOIN base_table b2
        ON b1."Team name" = b2."Team name"
        AND b1."Race ID" = b2."Race ID"
        AND b1."Driver name" < b2."Driver name"
),
final_output_table AS (
    SELECT
        pt."Team name",
        pt."Driver #1 name",
        pt."Driver #1 points",
        pt."Driver #1 rolling STDDEV",
        pt."Driver #2 name",
        pt."Driver #2 points",
        pt."Driver #2 rolling STDDEV",
        pt."Race ID",
        pt."Team/Drivers combo race counter"
    FROM pairs_table pt
    WHERE "Team/Drivers combo race counter" >= 10
)

SELECT * FROM final_output_table ORDER BY "Team name" ASC, "Race ID" ASC;

SELECT * 
FROM pairs_table 
WHERE "Driver #1 name" = 'barbazza'
ORDER BY "Race ID";

SELECT * FROM results;


/*
PLACEHOLDER TABLE OVERVIEW
*/
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public';


