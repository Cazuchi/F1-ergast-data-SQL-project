/*
THIS IS THE SCHEMA FILE FOR THE POSTGRES SQL DATABASE THAT'LL RUN LOCALLY IN DOCKER. IT IMPORTS DATA AND FORMATS IT INTO THE CORRECT TABLES WITH PROPER RELATIONSHIPS BETWEEN TABLES.
SOME VARIABLES FROM THE ORIGINAL F1 ERGAST DATASET ARE LEFT OUT ON PURPOSE. I'VE ONLY INCLUDED WHAT I THOUGHT WAS MOST INTERESTING / USEFUL.
*/

/*
DEFINE AND IMPORT STAGING TABLES:
All staging tables are created in this section. These are only used as temporary tables used to rename variables, so variables names don't class with reserved SQL variable names.
These are all deleted again in a lower section.

Edit: Apparently POSTGRES throws a fit if I try to skip columns during imports, so now these are used to import all columns as well and then the unnecessary ones are dumped again...
Makes it easier for the import code to process it, I guess.. It's whatever.
*/

CREATE TABLE drivers_staging_table (
    driverId INT,
    driverRef VARCHAR(255),
    "number" VARCHAR(255),
    code VARCHAR(255),
    forename VARCHAR(255),
    surname VARCHAR(255),
    dob VARCHAR(255),
    nationality VARCHAR(255),
    "url" VARCHAR(255)
);

COPY drivers_staging_table (driverId, driverRef, "number", code, forename, surname, dob, nationality, "url") 
FROM '/data/drivers.csv' DELIMITER ',' CSV HEADER;

CREATE TABLE constructors_staging_table (
    constructorId INT,
    constructorRef VARCHAR(255),
    "name" VARCHAR(255),
    nationality VARCHAR(255),
    "url" VARCHAR(255)
);

COPY constructors_staging_table (constructorId, constructorRef, "name", nationality, "url") 
FROM '/data/constructors.csv' DELIMITER ',' CSV HEADER;

CREATE TABLE circuits_staging_table (
    circuitId INT,
    circuitRef VARCHAR(255),
    "name" VARCHAR(255),
    "location" VARCHAR(255),
    country VARCHAR(255),
    lat VARCHAR(255),
    lng VARCHAR(255),
    alt INT,
    "url" VARCHAR(255)
);

COPY circuits_staging_table (circuitId, circuitRef, "name", "location", country, lat, lng, alt, "url") 
FROM '/data/circuits.csv' DELIMITER ',' CSV HEADER;

CREATE TABLE race_statuscodes_staging_table (
    statusId INT,
    "status" VARCHAR(255)
);

COPY race_statuscodes_staging_table (statusId, "status") 
FROM '/data/status.csv' DELIMITER ',' CSV HEADER;

CREATE TABLE races_staging_table (
    raceId INT,
    "year" INT,
    "round" VARCHAR(255),
    circuitId INT,
    "name" VARCHAR(255),
    "date" VARCHAR(255),
    "time" VARCHAR(255),
    "url" VARCHAR(255),
    fp1_date VARCHAR(255),
    fp1_time VARCHAR(255),
    fp2_date VARCHAR(255),
    fp2_time VARCHAR(255),
    fp3_date VARCHAR(255),
    fp3_time VARCHAR(255),
    quali_date VARCHAR(255),
    quali_time VARCHAR(255),
    sprint_date VARCHAR(255),
    sprint_time VARCHAR(255)
);

COPY races_staging_table (raceId, "year", "round", circuitId, "name", "date", "time", "url", fp1_date, fp1_time, fp2_date, fp2_time, fp3_date, fp3_time, quali_date, quali_time, sprint_date, sprint_time) 
FROM '/data/races.csv' DELIMITER ',' CSV HEADER;

CREATE TABLE results_staging_table (
    resultId VARCHAR(255),
    raceId INT,
    driverId INT,
    constructorId INT, 
    "number" VARCHAR(255),
    grid VARCHAR(255),
    position VARCHAR(255), 
    positionText VARCHAR(255),
    positionOrder VARCHAR(255),
    points VARCHAR(255), 
    laps INT, 
    "time" VARCHAR(255),
    milliseconds VARCHAR(255),
    fastestLap VARCHAR(255),
    "rank" VARCHAR(255),
    fastestLapTime VARCHAR(255),
    fastestLapSpeed VARCHAR(255),
    statusId INT
);

COPY results_staging_table (resultId, raceId, driverId, constructorId, "number", grid, position, positionText, positionOrder, points, laps, "time", milliseconds, fastestLap, "rank", fastestLapTime, fastestLapSpeed, statusId) 
FROM '/data/results.csv' DELIMITER ',' CSV HEADER;

CREATE TABLE constructor_standings_staging_table (
    constructorStandingsId VARCHAR(255),
    raceId INT,
    constructorId INT,
    points VARCHAR(255),
    position INT,
    positionText VARCHAR(255),
    wins INT
);

COPY constructor_standings_staging_table (constructorStandingsId, raceId, constructorId, points, position, positionText, wins) 
FROM '/data/constructor_standings.csv' DELIMITER ',' CSV HEADER;

CREATE TABLE constructor_results_staging_table (
    constructorResultsId VARCHAR(255),
    raceId INT,
    constructorId INT,
    points VARCHAR(255),
    "status" VARCHAR(255)
);

COPY constructor_results_staging_table (constructorResultsId, raceId, constructorId, points, "status") 
FROM '/data/constructor_results.csv' DELIMITER ',' CSV HEADER;

CREATE TABLE driver_standings_staging_table (
    driverStandingsId VARCHAR(255),
    raceId INT,
    driverId INT,
    points VARCHAR(255),
    position INT,
    positionText VARCHAR(255),
    wins INT
);

COPY driver_standings_staging_table (driverStandingsId, raceId, driverId, points, position, positionText, wins)
FROM '/data/driver_standings.csv' DELIMITER ',' CSV HEADER;

CREATE TABLE lap_times_staging_table (
    raceId INT,
    driverId INT,
    lap INT,
    position INT,
    "time" VARCHAR(255),
    milliseconds INT
);

COPY lap_times_staging_table (raceId, driverId, lap, position, "time", milliseconds)
FROM '/data/lap_times.csv' DELIMITER ',' CSV HEADER;

CREATE TABLE pit_stops_staging_table (
    raceId INT,
    driverId INT,
    "stop" INT,
    lap INT,
    "time" VARCHAR(255),
    duration VARCHAR(255),
    milliseconds INT
);

COPY pit_stops_staging_table (raceId, driverId, "stop", lap, "time", duration, milliseconds)
FROM '/data/pit_stops.csv' DELIMITER ',' CSV HEADER;

/*
DEFINE AND IMPORT DIMENSION TABLES
*/

CREATE TABLE drivers (
    driverId INT PRIMARY KEY,
    driverRef VARCHAR(255)
);

INSERT INTO drivers (driverId, driverRef)
SELECT driverId, driverRef FROM drivers_staging_table;

CREATE TABLE constructors (
    constructorId INT PRIMARY KEY,
    constructorName VARCHAR(255)
);

INSERT INTO constructors (constructorId, constructorName)
SELECT constructorId, "name" FROM constructors_staging_table;

CREATE TABLE circuits (
    circuitId INT PRIMARY KEY,
    circuitName VARCHAR(50),
    altitude INT
);

INSERT INTO circuits (circuitId, circuitName, altitude)
SELECT circuitId, "name", alt FROM circuits_staging_table;

CREATE TABLE race_statuscodes (
    statusId INT PRIMARY KEY,
    statusCode VARCHAR(50)
);

INSERT INTO race_statuscodes (statusId, statusCode)
SELECT statusId, "status" FROM race_statuscodes_staging_table;

CREATE TABLE races (
    raceId INT PRIMARY KEY,
    raceYear INT,
    circuitId INT REFERENCES circuits(circuitId),
    raceStart VARCHAR(255),
);

INSERT INTO races (raceId, raceYear, circuitId, raceStart)
SELECT raceId, "year", circuitId, NULLIF("time", '\N')::INTERVAL FROM races_staging_table;

/*
DEFINE AND IMPORT FACT TABLES
*/

CREATE TABLE results (
    raceId INT REFERENCES races(raceId),
    driverId INT REFERENCES drivers(driverId),
    constructorId INT REFERENCES constructors(constructorId), 
    position INT, 
    points INT, 
    laps INT, 
    totalRaceTime VARCHAR(255),
    milliseconds INT, 
    fastestLap INT,
    fastestLapRank INT, 
    fastestLapTime VARCHAR(255),
    fastestLapSpeed NUMERIC, 
    statusId INT REFERENCES race_statuscodes(statusId)
);

INSERT INTO results (raceId, driverId, constructorId, position, points, laps, totalRaceTime, milliseconds, fastestLap, fastestLapRank, fastestLapTime, fastestLapSpeed, statusId)
SELECT raceId, driverId, constructorId, NULLIF(position, '\N')::INT, NULLIF(points, '\N')::NUMERIC, laps, NULLIF("time", '\N')::INTERVAL, NULLIF(milliseconds, '\N')::INT, NULLIF(fastestLap, '\N')::INT, NULLIF("rank", '\N')::INT, NULLIF(fastestLapTime, '\N')::INTERVAL, NULLIF(fastestLapSpeed, '\N')::NUMERIC, statusId FROM results_staging_table;

CREATE TABLE constructor_standings (
    raceId INT REFERENCES races(raceId),
    constructorId INT REFERENCES constructors(constructorId),
    points INT,
    position INT,
    wins INT
);

INSERT INTO constructor_standings (raceId, constructorId, points, position, wins)
SELECT raceId, constructorId, NULLIF(points, '\N')::NUMERIC, position, wins FROM constructor_standings_staging_table;

CREATE TABLE constructor_results (
    raceId INT REFERENCES races(raceId),
    constructorId INT REFERENCES constructors(constructorId),
    points INT
);

INSERT INTO constructor_results (raceId, constructorId, points)
SELECT raceId, constructorId, NULLIF(points, '\N')::NUMERIC FROM constructor_results_staging_table;

CREATE TABLE driver_standings (
    raceId INT REFERENCES races(raceId),
    driverId INT REFERENCES drivers(driverId),
    points INT,
    position INT,
    wins INT
);

INSERT INTO driver_standings (raceId, driverId, points, position, wins)
SELECT raceId, driverId, NULLIF(points, '\N')::NUMERIC, position, wins FROM driver_standings_staging_table;

CREATE TABLE lap_times (
    raceId INT REFERENCES races(raceId),
    driverId INT REFERENCES drivers(driverId),
    lap INT,
    position INT,
    lap_time VARCHAR(255),
    milliseconds INT
);

INSERT INTO lap_times (raceId, driverId, lap, position, lap_time, milliseconds)
SELECT raceId, driverId, lap, position, "time", milliseconds FROM lap_times_staging_table;

CREATE TABLE pit_stops (
    raceId INT REFERENCES races(raceId),
    driverId INT REFERENCES drivers(driverId),
    stopNumber INT,
    lap INT,
    pitStopTime VARCHAR(255),
    duration VARCHAR(255),
    milliseconds INT
);

INSERT INTO pit_stops (raceId, driverId, stopNumber, lap, pitStopTime, duration, milliseconds)
SELECT raceId, driverId, "stop", lap, "time", duration, milliseconds from pit_stops_staging_table;

/*
DELETION AREAS:
Organized area for deleting temporary staging tables. These have served their purpose and will only clutter the final database.
*/

DROP TABLE drivers_staging_table;
DROP TABLE constructors_staging_table;
DROP TABLE circuits_staging_table;
DROP TABLE race_statuscodes_staging_table;
DROP TABLE races_staging_table;
DROP TABLE results_staging_table;
DROP TABLE constructor_standings_staging_table;
DROP TABLE constructor_results_staging_table;
DROP TABLE driver_standings_staging_table;
DROP TABLE lap_times_staging_table;
DROP TABLE pit_stops_staging_table;