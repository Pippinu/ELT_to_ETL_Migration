-- Create raw schema
CREATE SCHEMA IF NOT EXISTS raw;

-- 1. TMDB Movies
CREATE OR REPLACE TABLE raw.tmdb_movies AS 
SELECT * FROM read_csv_auto('/home/alessio/Documents/ELT_GAV/movie_analytics/data/raw/tmdb_5000_movies.csv');

-- 2. TMDB Credits
CREATE OR REPLACE TABLE raw.tmdb_credits AS 
SELECT * FROM read_csv_auto('/home/alessio/Documents/ELT_GAV/movie_analytics/data/raw/tmdb_5000_credits.csv');

-- 3. Box Office
CREATE OR REPLACE TABLE raw.box_office AS 
SELECT * FROM read_csv_auto('/home/alessio/Documents/ELT_GAV/movie_analytics/data/raw/moviesboxoffice.csv');

-- 4. IMDb Names (name.basics)
CREATE OR REPLACE TABLE raw.imdb_names AS 
SELECT * FROM read_csv_auto('/home/alessio/Documents/ELT_GAV/movie_analytics/data/raw/name.basics.tsv', delim='\t');