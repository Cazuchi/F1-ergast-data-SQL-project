# Setting up a local docker PostgreSQL database and exploring the F1 Ergast dataset using SQL
This is my main repo for showcasing my SQL competency. The project is entirely self-contained and can be cloned and run as is to use both the docker SQL 
database and the queries that I have written. I have specifically chosen a subset of the Ergast F1 dataset that I found to be the most interesting in 
my initial inspection of the data, used SQL to define and populate the database tables and then used SQL to combine individual tables into two separate 
output tables that each highlights different aspects of the dataset, using different SQL approaches.

The queries to create the output are written in the [analysis.sql](https://github.com/Cazuchi/F1-ergast-data-SQL-project/blob/main/Analysis.sql) files, which includes the two queries along with a few setup commands for temporary tables 
and commentary explaining what my approach was for the dataset and what I found interesting about the output from each query. Each query also includes 
multiple SELECT FROM / ORDER BY statements at the bottom, which are meant to be used one at a time, which is why all but one are commented out by default. 
Each of those SELECT FROM / ORDER BY statements highlight an interesting finding from the rather large output tables, that would otherwise be harder to see 
without sorting it in specific ways.

## Features
Two queries with different purposes:
- Query #1 looks at individual racers performance over time and compares metrics like avg. points per win, historical standard deviation for points etc., 
  with the purpose of looking at interesting differences between the different drivers' performance.

- Query #2 looks at unique combinations of teams and drivers and specifically highlight potential strategic choices made by team when choosing what drivers 
  to hire. As in, did a team choose two high volatility drivers or a more balanced pairing of drivers for their new team? How did the drivers standard deviation 
  in points scored develop over while while in that unique pairing of teams and drivers? Amongst other questions. This query also tackles the classic gaps and 
  islands problem, in order to be able to correctly split unique combinations of teams and drivers into stint. As a unique combination of a team and two drivers 
  can potentially be repeated later in time, with a gap in between, the gaps and islands approach allows for those two stints to be correctly identified.

## Recommended tooling (what I used) 
- VS Code for displaying the code and running the queries 
    - The Docker / Container Tools extension for VS Code 
    - The SQLTools & SQLTools PostgreSQL extensions for VS Code 
- Docker

Spin up the Docker database using the command `docker compose up -d` in PowerShell.

## Data Sources
- F1 Ergast dataset from Kaggle: https://www.kaggle.com/datasets/rohanrao/formula-1-world-championship-1950-2020?resource=download

## Tech Stack
- SQL
- Docker