/*
This script is my analytical findings from looking through the dataset and seeing
what interesting results I could find across the different tables. Each query has an
associated comment denoting what my goal with the query was and why I think that the
result of the query is interesting.
*/

SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public';

CREATE TABLE modern_points_system (
    position INT,
    modern_points INT
);

INSERT INTO modern_points_system (position, modern_points) VALUES
(1, 25),(2, 18),(3, 15),(4, 12),(5, 10),(6, 8),(7, 6),(8, 4),(9, 2),(10, 1);

CREATE TABLE points_for_fastest_lap (
    fastestlaprank INT,
    bonus_points INT
);

INSERT INTO points_for_fastest_lap (fastestlaprank, bonus_points) VALUES
(1, 1);

WITH adjusted_results as (
    SELECT r.raceid, r.driverid, r.position, r.fastestlaprank, COALESCE(mps.modern_points, 0) AS modern_points
    FROM results r
    LEFT JOIN modern_points_system mps ON r.position = mps.position
),
adjusted_results_with_bonus as (
    SELECT ar.raceid, ar.driverid, ar.position, ar.fastestlaprank, ar.modern_points, COALESCE(pffl.bonus_points, 0) as bonus_points
    FROM adjusted_results ar
    LEFT JOIN points_for_fastest_lap pffl ON ar.fastestlaprank = pffl.fastestlaprank
),
Career_points_table as (
    SELECT
        d.driverref AS "Driver name",
        SUM(arwb.modern_points) + sum(arwb.bonus_points) AS "Career points",
        COUNT(DISTINCT arwb.raceid) AS "Races entered",
        (SUM(arwb.modern_points) + sum(arwb.bonus_points)) / COUNT(DISTINCT arwb.raceid) AS "Avg. points per race",
        MIN(rc.raceyear) AS "First season",
        MAX(rc.raceyear) AS "Latest season",
        MAX(rc.raceyear) - MIN(rc.raceyear) + 1 AS "Years active in racing",
        (SUM(arwb.modern_points) + sum(arwb.bonus_points)) / (MAX(rc.raceyear) - MIN(rc.raceyear)) AS "Avg. points per year active in racing",
        2026 - MAX(rc.raceyear) AS "Years since last active in a race"
    FROM adjusted_results_with_bonus arwb
    INNER JOIN drivers d ON arwb.driverid = d.driverid
    INNER JOIN races rc ON arwb.raceid = rc.raceid
    GROUP BY d.driverref
    HAVING (SUM(arwb.modern_points) + sum(arwb.bonus_points)) >= 1000
)

SELECT * FROM Career_points_table ORDER BY "Avg. points per year active in racing" DESC, "Avg. points per race" DESC;
-- SELECT * FROM Career_points_table ORDER BY "Latest season" DESC, "Avg. points per race" DESC;



SELECT * from results





