# Data Management - Project Proposal

**Group Members:**
- **Name Surname:** Alessio Iacono 
- **Student ID:** 1870276
---

### Chosen Type of Project

**[DW]** Select a set of data sources, integrate them by means of ETL operations (you can either use an integration tool or
write simple scripts to solve common ETL problems), define the DFM model for your data, define and populate the
corresponding star schema or snowflake schema, by using a relational DB (e.g., Postgres). Perform OLAP queries.

Focus: ability to combine data from different datasets in order to produce a relevant unified source of analysis

---

### Description of Dataset(s)
The project integrates movie, cast, and revenue data from three distinct external sources:

1. **TMDB (The Movie Database):** Contains metadata regarding movies, detailed credits (cast & crew), genres, and keywords.  
   * *Reference Link:* [Kaggle - TMDB 5000 Movie Dataset](https://www.kaggle.com/datasets/tmdb/tmdb-movie-metadata)
2. **IMDB Data Dumps:** Publicly available TSV datasets providing comprehensive actor profiles, primary titles, and principal roles.  
   * *Reference Link:* [IMDB Non-Commercial Datasets](https://developer.imdb.com/non-commercial-datasets/)
3. **BoxOffice Mojo / Financial Metadata:** Web-scraped and structured financial performance records (budget, domestic/gross revenue).  
   * *Reference Link:* [Kaggle - Movie Industry Dataset](https://www.kaggle.com/datasets/danielgrijalvas/movies)

---

### Brief Description of the Intended Work
This project aims to re-engineer an existing Apache NiFi movie ETL pipeline into a modern ELT data architecture using **dbt (data build tool)** on PostgreSQL. Instead of carrying out data transformations in-flight within NiFi processors, raw dataset files will be loaded directly into a relational staging layer. 

The transformation, entity integration, and data quality enforcement will be managed declaratively through SQL-based dbt models structured across three layers:
1. **Staging Models (`stg_`):** Standardizing data types, cleaning column names, and casting raw fields.
2. **Intermediate Models (`int_`):** Handling entity resolution, cross-source lookups (mapping `tmdb_id` to composite natural keys), and enforcing key consistency across actor and genre dictionaries.
3. **Marts / Global Schema (`fct_` / `dim_`):** Building the target analytical schema (`movies`, `actors`, `genres`, and their respective M:N bridge tables).

Finally, native dbt tests (`unique`, `not_null`, `relationships`) will be configured to validate relational integrity constraints, and complete end-to-end DAG data lineage documentation will be generated via `dbt docs`.