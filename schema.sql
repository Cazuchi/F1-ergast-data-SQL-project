/*
THIS IS THE SCHEMA FILE FOR THE POSTGRES SQL DATABASE THAT'LL RUN LOCALLY IN DOCKER. IT IMPORTS DATA AND FORMATS IT INTO THE CORRECT TABLES WITH PROPER RELATIONSHIPS BETWEEN TABLES.
SOME VARIABLES FROM THE ORIGINAL F1 ERGAST DATASET ARE LEFT OUT ON PURPOSE. I'VE ONLY INCLUDED WHAT I THOUGHT WAS MOST INTERESTING / USEFUL.
*/

/*
DIMENSION TABLES:
All dimension tables are created in this section. There's a staging tables section further down for creating staging tables which have to sole purpose of being placeholders used for renaming variables. 
Those aren't saved in the final database.
*/

CREATE TABLE drivers (
    driverId INT PRIMARY KEY,
    driverRef VARCHAR(50)
);

CREATE TABLE constructors (
    constructorId INT PRIMARY KEY,
    constructorName VARCHAR(50)
);

CREATE TABLE circuits (
    circuitId INT PRIMARY KEY,
    circuitName VARCHAR(50),
    altitude INT
);

CREATE TABLE race_statuscodes (
    statusId INT PRIMARY KEY,
    statusCode VARCHAR(50)
);

CREATE TABLE races (
    raceId INT PRIMARY KEY,
    raceYear INT,
    circuitId INT REFERENCES circuits(circuitId),
    raceStart INTERVAL
);

/*
FACT TABLES:
All fact tables are created in this section. There's a staging tables section further down for creating staging tables which have to sole purpose of being placeholders used for renaming variables. 
Those aren't saved in the final database.
*/

CREATE TABLE results (
    raceId INT REFERENCES races(raceId),
    driverId INT REFERENCES drivers(driverId),
    constructorId INT REFERENCES constructors(constructorId), 
    position INT, 
    points INT, 
    laps INT, 
    totalRaceTime INTERVAL,
    milliseconds INT, 
    fastestLap INT, 
    fastestLapTime INTERVAL,
    fastestLapSpeed NUMERIC, 
    statusId INT REFERENCES race_statuscodes(statusId)
);

CREATE TABLE constructor_standings (
    raceId INT REFERENCES races(raceId),
    constructorId INT REFERENCES constructors(constructorId),
    points INT,
    position INT,
    wins INT
);

CREATE TABLE constructor_results (
    raceId INT REFERENCES races(raceId),
    constructorId INT REFERENCES constructors(constructorId),
    points INT
);

CREATE TABLE driver_standings (
    raceId INT REFERENCES races(raceId),
    driverId INT REFERENCES drivers(driverId),
    points INT,
    position INT,
    wins INT
);

CREATE TABLE lap_times (
    raceId INT REFERENCES races(raceId),
    driverId INT REFERENCES drivers(driverId),
    lap INT,
    position INT,
    lap_time INTERVAL,
    milliseconds INT
);

CREATE TABLE pit_stops (
    raceId INT REFERENCES races(raceId),
    driverId INT REFERENCES drivers(driverId),
    stopNumber INT,
    lap INT,
    pitStopTime INTERVAL,
    duration NUMERIC,
    milliseconds INT
);

/*
STAGING TABLES:
All staging tables are created in this section. These are only used as temporary tables used to rename variables, so variables names don't class with reserved SQL variable names.
These are all deleted again in a lower section.
*/

CREATE TABLE constructors_staging_table (
    constructorId INT PRIMARY KEY,
    "name" VARCHAR(50)
);

CREATE TABLE circuits_staging_table (
    circuitId INT PRIMARY KEY,
    "name" VARCHAR(50),
    alt INT
);

CREATE TABLE race_statuscodes_staging_table (
    statusId INT PRIMARY KEY,
    "status" VARCHAR(50)
);

CREATE TABLE races_staging_table (
    raceId INT PRIMARY KEY,
    "year" INT,
    circuitId INT,
    "time" INTERVAL
);

CREATE TABLE results_staging_table (
    raceId INT,
    driverId INT,
    constructorId INT, 
    position INT, 
    points INT, 
    laps INT, 
    "time" INTERVAL,
    milliseconds INT, 
    fastestLap INT, 
    fastestLapTime INTERVAL,
    fastestLapSpeed NUMERIC, 
    statusId INT
);

CREATE TABLE lap_times_staging_table (
    raceId INT,
    driverId INT,
    lap INT,
    position INT,
    "time" INTERVAL,
    milliseconds INT
);

CREATE TABLE pit_stops_staging_table (
    raceId INT,
    driverId INT,
    "stop" INT,
    lap INT,
    "time" INTERVAL,
    duration NUMERIC,
    milliseconds INT
);

/*
IMPORTS:
Section for organizing all data imports. All data tables come from .csv files in this case. All .csv files are included in the repository.
*/

COPY drivers (driverId, driverRef) 
FROM 'C:\Users\mikee\Desktop\Projects\F1-ergast-data-SQL-project\F1-Ergast-data-files\drivers.csv' DELIMITER ',' CSV HEADER;

COPY constructors_staging_table (constructorId, "name") 
FROM 'C:\Users\mikee\Desktop\Projects\F1-ergast-data-SQL-project\F1-Ergast-data-files\constructors.csv' DELIMITER ',' CSV HEADER;

COPY circuits_staging_table (circuitId, "name", alt) 
FROM 'C:\Users\mikee\Desktop\Projects\F1-ergast-data-SQL-project\F1-Ergast-data-files\circuits.csv' DELIMITER ',' CSV HEADER;

COPY race_statuscodes_staging_table (statusId, "status") 
FROM 'C:\Users\mikee\Desktop\Projects\F1-ergast-data-SQL-project\F1-Ergast-data-files\status.csv' DELIMITER ',' CSV HEADER;

COPY races_staging_table (raceId, "year", circuitId, "time") 
FROM 'C:\Users\mikee\Desktop\Projects\F1-ergast-data-SQL-project\F1-Ergast-data-files\races.csv' DELIMITER ',' CSV HEADER;

COPY results_staging_table (raceId, driverId, constructorId, position, points, laps, "time", milliseconds, fastestLap, fastestLapTime, fastestLapSpeed, statusId) 
FROM 'C:\Users\mikee\Desktop\Projects\F1-ergast-data-SQL-project\F1-Ergast-data-files\results.csv' DELIMITER ',' CSV HEADER;

COPY lap_times_staging_table (raceId, driverId, lap, position, "time", milliseconds)
FROM 'C:\Users\mikee\Desktop\Projects\F1-ergast-data-SQL-project\F1-Ergast-data-files\lap_times.csv' DELIMITER ',' CSV HEADER;

COPY pit_stops_staging_table (raceId, driverId, "stop", lap, "time", duration, milliseconds)
FROM 'C:\Users\mikee\Desktop\Projects\F1-ergast-data-SQL-project\F1-Ergast-data-files\pit_stops.csv' DELIMITER ',' CSV HEADER;

/*
RENAMING AREA:
Some of the imported tables from the .csv files use headers reserved in the SQL namespace.
I don't want to have to use quotes, so these are renamed here.

Sidenote: There has to be a better way to rename headers than renaming while copying all variables from one table to another. Maybe just use Python for this step next time during data exploration...
*/

INSERT INTO constructors (constructorId, constructorName)
SELECT constructorId, "name" FROM constructors_staging_table;

INSERT INTO circuits (circuitId, circuitName, altitude)
SELECT circuitId, "name", alt FROM circuits_staging_table;

INSERT INTO race_statuscodes (statusId, statusCode)
SELECT statusId, "status" FROM race_statuscodes_staging_table;

INSERT INTO races (raceId, raceYear, circuitId, raceStart)
SELECT raceId, "year", circuitId, "time" FROM races_staging_table;

INSERT INTO results (raceId, driverId, constructorId, position, points, laps, totalRaceTime, milliseconds, fastestLap, fastestLapTime, fastestLapSpeed, statusId)
SELECT raceId, driverId, constructorId, position, points, laps, "time", milliseconds, fastestLap, fastestLapTime, fastestLapSpeed, statusId FROM results_staging_table;

INSERT INTO lap_times (raceId, driverId, lap, position, lap_time, milliseconds)
SELECT raceId, driverId, lap, position, "time", milliseconds FROM lap_times_staging_table;

INSERT INTO pit_stops (raceId, driverId, stopNumber, lap, pitStopTime, duration, milliseconds)
SELECT raceId, driverId, "stop", lap, "time", duration, milliseconds from pit_stops_staging_table;

/*
SECONDARY IMPORTS:
THESE REFERENCE VARIABLES IN THAT AREN'T AVAILABLE UNTIL AFTER THE RENAME SECTIONS, WHICH IS WHY THEY'RE IMPORTED HERE INSTEAD OF IN THE INITIAL IMPORT SECTION.
*/

COPY constructor_standings (raceId, constructorId, points, position, wins) 
FROM 'C:\Users\mikee\Desktop\Projects\F1-ergast-data-SQL-project\F1-Ergast-data-files\constructor_standings.csv' DELIMITER ',' CSV HEADER;

COPY constructor_results (raceId, constructorId, points) 
FROM 'C:\Users\mikee\Desktop\Projects\F1-ergast-data-SQL-project\F1-Ergast-data-files\constructor_results.csv' DELIMITER ',' CSV HEADER;

COPY driver_standings (raceId, driverId, points, position, wins)
FROM 'C:\Users\mikee\Desktop\Projects\F1-ergast-data-SQL-project\F1-Ergast-data-files\driver_standings.csv' DELIMITER ',' CSV HEADER;

/*
DELETION AREAS:
Organized area for deleting temporary staging tables. These have served their purpose and will only clutter the final database.
*/

DROP TABLE constructors_staging_table;
DROP TABLE circuits_staging_table;
DROP TABLE race_statuscodes_staging_table;
DROP TABLE races_staging_table;
DROP TABLE results_staging_table;
DROP TABLE lap_times_staging_table;
DROP TABLE pit_stops_staging_table;