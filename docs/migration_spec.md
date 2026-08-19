# NiFi-to-dbt Migration Specification

## 1. Objective and Scope

### 1.1 Objective

This project migrates an existing Apache NiFi and PostgreSQL ETL pipeline to a local ELT pipeline based on DuckDB and dbt.

The original pipeline integrates movie-related datasets from TMDB, Box Office, and IMDb. NiFi performs file ingestion, record-level transformations, lookups, filtering, and loading into PostgreSQL. The new pipeline will instead load raw source files into DuckDB and express transformations as version-controlled dbt SQL models.

The first implementation goal is **functional equivalence**: the dbt project must reproduce the intended final relational model and business rules of the legacy NiFi/PostgreSQL pipeline before introducing model redesigns or additional data sources.

### 1.2 ELT Principles

The new pipeline follows these principles:

- Raw downloaded files remain unchanged and are treated as immutable source data.
- Transformations previously performed in the Pandas preprocessing notebook and Apache NiFi are implemented inside DuckDB through dbt models.
- Each transformation is explicit, deterministic, testable, and documented.
- dbt model dependencies replace the execution order and lookup flow expressed visually in the NiFi canvas.
- Data quality rules previously enforced through PostgreSQL primary keys and foreign keys are represented by dbt tests.
- Invalid, unmatched, or excluded records should be observable through optional audit models instead of being silently discarded.

### 1.3 In Scope

Version 1 includes the following tasks:

1. Read the five raw source files from a local project directory.
2. Apply the preprocessing rules defined in the legacy project:
   - rename source-specific columns;
   - convert null markers and invalid values to SQL `NULL`;
   - safely cast numeric and temporal values;
   - derive movie release year from TMDB release date;
   - remove unused source attributes from the analytical transformation path;
   - flatten TMDB JSON arrays for genres and cast members;
   - deduplicate records according to the legacy business keys.
3. Reproduce the original integration and source-precedence logic.
4. Create the final `global` relational model in DuckDB:
   - `global.movies`
   - `global.actors`
   - `global.genres`
   - `global.movieactors`
   - `global.moviegenres`
5. Add dbt tests corresponding to the legacy primary-key, foreign-key, and semantic-quality rules.
6. Create audit models for important exclusions, such as invalid movie keys or unmatched references.
7. Validate the new results against the legacy PostgreSQL output where an old database dump or equivalent result is available.

### 1.4 Final Target Model

The final DuckDB `global` schema preserves the legacy PostgreSQL interface.

| Relation | Attributes | Primary Key | Purpose |
|---|---|---|---|
| `global.movies` | `title`, `year`, `tmdbid`, `votecount`, `voteaverage`, `budget`, `revenueworldwide`, `revenuedomestic`, `profit` | `(title, year)` | Integrated movie entity containing TMDB metadata and Box Office financial data |
| `global.actors` | `actorname`, `birthyear`, `deathyear` | `actorname` | IMDb-derived actor biographical entity |
| `global.genres` | `genrename` | `genrename` | Dictionary of distinct genre names |
| `global.movieactors` | `title`, `year`, `actorname` | `(title, year, actorname)` | Bridge relation between movies and actors |
| `global.moviegenres` | `title`, `year`, `genrename` | `(title, year, genrename)` | Bridge relation between movies and genres |

The bridge relations must reference existing parent entities:

- `global.movieactors.(title, year)` references `global.movies.(title, year)`.
- `global.movieactors.actorname` references `global.actors.actorname`.
- `global.moviegenres.(title, year)` references `global.movies.(title, year)`.
- `global.moviegenres.genrename` references `global.genres.genrename`.

### 1.5 Compatibility Decisions

The following existing design decisions are retained in Version 1 to preserve compatibility:

- Movies are identified in the final model by the natural key `(title, year)`, while the TMDB identifier is retained as the `tmdbid` attribute.
- Actors are identified by `actorname` under the legacy **Unique Name Assumption**.
- The full IMDb `nconst` identifier is retained only in the raw/staging path for traceability; it is not part of the Version 1 final `global.actors` table.
- Box Office and TMDB worldwide-revenue values are reconciled using the legacy source-preference policy: when both sources provide a value for the same integrated movie, the Box Office value takes precedence.
- `profit` is calculated as `revenueworldwide - budget` only when both operands are available; otherwise it is `NULL`.
- Genre and actor bridge rows are emitted only when their referenced movie and dimension entity exist in the final model.

These decisions are compatibility constraints, not claims that they are ideal long-term identity-resolution policies. Future versions may introduce stable identifiers and more robust cross-source matching.

### 1.6 Out of Scope

Version 1 does not include:

- Replacing natural keys with surrogate keys or redesigning the final schema.
- Full IMDb title, ratings, principals, or title-crew integration.
- Fuzzy matching between IMDb, TMDB, and Box Office movie titles.
- A production deployment, cloud warehouse, scheduler, or incremental-loading strategy.
- Recreating NiFi operational features such as file polling, retry policies, back pressure, or NiFi state management.
- Benchmarking DuckDB against Pandas, Polars, or PySpark.
- Advanced analytics or machine-learning models built on top of the warehouse.

The project is intentionally local and batch-oriented: raw files are downloaded manually, DuckDB is the analytical database, and dbt is responsible for data transformation, testing, documentation, and lineage.

## 2. Source Inventory

### 2.1 Source Management Policy

All inputs must be stored under `data/raw/` without modifying their content.

The dbt project must read raw files directly from this directory. It must not depend on the normalized CSV/TSV outputs generated by the legacy Pandas notebook, because those preprocessing steps will be reimplemented as dbt transformations.

The expected raw files are listed below. Exact filenames may differ from the original project layout, but their source identity, format, and columns must remain compatible with this specification.

### 2.2 Box Office Movies

| Property | Specification |
|---|---|
| Logical source name | `boxoffice_movies` |
| Expected raw filename | `moviesboxoffice.csv` |
| Format | CSV |
| Delimiter | Comma (`,`) |
| Encoding | UTF-8 unless inspection shows otherwise |
| Approximate legacy size | 5,000 rows before preprocessing |
| Role | Financial enrichment source for the integrated movie entity |
| Business key after staging | `(title, year)` |

Relevant raw columns:

| Raw column | Staged column | Intended type | Notes |
|---|---|---|---|
| `Release Group` | `title` | `VARCHAR` | Movie title |
| `Year` | `year` | `INTEGER` | Release year |
| `Worldwide` | `revenueworldwide` | `BIGINT` | Worldwide box-office revenue |
| `Domestic` | `revenuedomestic` | `BIGINT` | Domestic box-office revenue |
| `Foreign` | `revenueforeign` | `BIGINT` | Retained in staging; not required by the Version 1 final model |

The legacy preprocessing removed unused columns, removed commas from revenue fields before numeric conversion, removed records with null `title` or `year`, and retained one record per `(title, year)` key.

### 2.3 TMDB Movies

| Property | Specification |
|---|---|
| Logical source name | `tmdb_movies` |
| Expected raw filename | `tmdb_5000_movies.csv` or `tmdb5000movies.csv` |
| Format | CSV |
| Delimiter | Comma (`,`) |
| Encoding | UTF-8 |
| Approximate legacy size | 4,803 rows |
| Role | Primary source of movie metadata and embedded genre data |
| Source key | `id`, renamed to `movieid` in staging |
| Final integration key | `(title, year)` |

Relevant raw columns:

| Raw column | Staged column | Intended type | Notes |
|---|---|---|---|
| `id` | `movieid` | `INTEGER` | TMDB movie identifier |
| `title` | `title` | `VARCHAR` | Movie title |
| `release_date` | `releasedate` | `DATE` | Used to derive `year` |
| Derived from `release_date` | `year` | `INTEGER` | Required by final movie natural key |
| `budget` | `budget` | `BIGINT` | Movie budget |
| `revenue` | `revenue` | `BIGINT` | TMDB worldwide revenue candidate |
| `vote_count` | `votecount` | `INTEGER` | TMDB voting count |
| `vote_average` | `voteaverage` | `DECIMAL(3,1)` | TMDB average rating |
| `genres` | `genres_json` | `VARCHAR` / JSON text | JSON array used to derive movie-genre rows |

The legacy preprocessing selected the listed movie attributes, derived `year` from `release_date`, excluded null `movieid` values, and deduplicated by `movieid`. A record with no parsable release date may remain in staging but cannot enter the Version 1 final `global.movies` model because `year` is part of its primary key.

### 2.4 TMDB Credits

| Property | Specification |
|---|---|
| Logical source name | `tmdb_credits` |
| Expected raw filename | `tmdb_5000_credits.csv` or `tmdb5000credits.csv` |
| Format | CSV |
| Delimiter | Comma (`,`) |
| Encoding | UTF-8 |
| Approximate legacy size | 4,803 rows before cast expansion |
| Role | Source of movie-to-actor relationships |
| Source key | `movie_id`, represented as `movieid` in the project |
| Derived bridge key | `(movieid, actorname)` |

Relevant raw columns:

| Raw column | Staged column | Intended type | Notes |
|---|---|---|---|
| `movie_id` | `movieid` | `INTEGER` | Links credits to TMDB movies |
| `title` | `source_title` | `VARCHAR` | Retained for diagnostics; not used as the authoritative join key |
| `cast` | `cast_json` | `VARCHAR` / JSON text | JSON array flattened into actor rows |
| `crew` | Not used in Version 1 | — | Excluded from the transformation path |

The `cast` JSON array contains actor objects. The migration must extract each object’s `name` attribute, emit one `(movieid, actorname)` row per actor, discard null keys, and deduplicate by `(movieid, actorname)`.

### 2.5 IMDb People

| Property | Specification |
|---|---|
| Logical source name | `imdb_people` |
| Expected raw filename | `name.basics.tsv` |
| Format | TSV |
| Delimiter | Tab (`\t`) |
| Encoding | UTF-8 |
| Null marker | `\N` |
| Approximate legacy normalized size | 650,213 rows |
| Role | Biographical enrichment source for actors |
| Raw identifier | `nconst` |
| Legacy final business key | `actorname` |

Relevant raw columns:

| Raw column | Staged column | Intended type | Notes |
|---|---|---|---|
| `nconst` | `imdb_person_id` | `VARCHAR` | Preserved in raw/staging for traceability |
| `primaryName` | `actorname` | `VARCHAR` | Legacy final actor identifier |
| `birthYear` | `birthyear` | `INTEGER` | Nullable |
| `deathYear` | `deathyear` | `INTEGER` | Nullable |
| `primaryProfession` | Not used in Version 1 | — | Available for future extension |
| `knownForTitles` | Not used in Version 1 | — | Available for future extension |

The migration must interpret `\N` as `NULL`, safely cast birth and death years, discard rows where both years are missing in the legacy-compatible actor-selection model, discard null actor names, and retain one row per `actorname` to implement the Unique Name Assumption.

This source is larger than the other inputs. DuckDB should read it directly from the raw TSV file; no pre-filtered or Pandas-normalized copy is required.

### 2.6 Derived Relations

The following relations are not independently downloaded sources. They were written as normalized files in the previous preprocessing notebook, but will be created as dbt models in this migration.

| Derived relation | Source | Target grain | Purpose |
|---|---|---|---|
| `tmdb_movie_genres` | TMDB movies `genres` JSON | One row per `(movieid, genrename)` | Normalized movie-to-genre source bridge |
| `tmdb_movie_actors` | TMDB credits `cast` JSON | One row per `(movieid, actorname)` | Normalized movie-to-actor source bridge |
| `stg_boxoffice_movies` | Raw Box Office file | One row per `(title, year)` | Cleaned financial source |
| `stg_tmdb_movies` | Raw TMDB movies file | One row per `movieid` | Cleaned TMDB movie source |
| `stg_imdb_people` | Raw IMDb people file | One row per raw IMDb person | Cleaned source-level people relation |

### 2.7 Required Source Checks

Before building transformations, the project must inspect each downloaded file and confirm:

1. Its filename and local path match the dbt source configuration.
2. Its delimiter, encoding, header names, and null markers match this inventory.
3. TMDB JSON columns are valid enough to parse with DuckDB JSON functions.
4. IMDb uses `\N` consistently as its missing-value marker.
5. The actual raw row counts are recorded in a short source-profile note.
6. Any source-version differences from the legacy project are documented before model logic is changed.

Raw row counts and file metadata are not treated as fixed tests because source providers may publish different snapshots. They are recorded to make the migration reproducible and to explain any later difference from the legacy PostgreSQL output.

## 3. Target Model and Business Rules

### 3.1 Target Layer

The final models are published in the DuckDB `global` schema and are the supported interface for downstream analytical queries.

The target model reproduces the legacy PostgreSQL tables, attribute names, natural keys, and referential constraints. dbt materialization details are an implementation decision and must not change the target model's logical contract.

The Version 1 target relations are:

| Relation | Grain | Materialization intent |
|---|---|---|
| `global.movies` | One row per `(title, year)` | Table |
| `global.actors` | One row per `actorname` | Table |
| `global.genres` | One row per `genrename` | Table |
| `global.movieactors` | One row per `(title, year, actorname)` | Table |
| `global.moviegenres` | One row per `(title, year, genrename)` | Table |

### 3.2 `global.movies`

`global.movies` is the core movie entity. TMDB is the driving source: a final movie row originates from a valid staged TMDB movie record.

A TMDB movie is eligible for publication only when:

- `movieid` is not null;
- `title` is not null;
- `year`, derived from `release_date`, is not null;
- it survives the staged TMDB deduplication rule of one record per `movieid`; and
- it survives final deduplication on the target key `(title, year)`.

Box Office-only movies do not enter `global.movies` in Version 1. This preserves the operational behavior of the NiFi flow, which reads TMDB movies as the primary source and uses Box Office only as a lookup-based enrichment source.

#### Columns

| Target column | Type | Nullability | Derivation |
|---|---|---|---|
| `title` | `VARCHAR` | Not null | TMDB `title` |
| `year` | `INTEGER` | Not null | Year extracted from TMDB `release_date` |
| `tmdbid` | `INTEGER` | Nullable | TMDB `movieid` |
| `votecount` | `INTEGER` | Nullable | TMDB `votecount` |
| `voteaverage` | `DECIMAL(3,1)` | Nullable | TMDB `voteaverage` |
| `budget` | `BIGINT` | Nullable | TMDB `budget` |
| `revenueworldwide` | `BIGINT` | Nullable | Box Office `revenueworldwide` when a lookup match exists; otherwise TMDB `revenue` |
| `revenuedomestic` | `BIGINT` | Nullable | Box Office `revenuedomestic` when a lookup match exists; otherwise `NULL` |
| `profit` | `BIGINT` | Nullable | `revenueworldwide - budget` when both values are non-null; otherwise `NULL` |

#### Revenue policy

For a TMDB movie that matches a Box Office record, Box Office is authoritative for worldwide and domestic revenue. The Box Office lookup is a business enrichment, not a separate source of movie rows.

For a TMDB movie with no Box Office match:

- `revenueworldwide` is populated from TMDB `revenue`;
- `revenuedomestic` is `NULL`;
- `profit` uses TMDB revenue minus TMDB budget when both values exist.

This follows the NiFi behavior: unmatched TMDB rows retain TMDB revenue under the final `revenueworldwide` attribute, while matched rows use Box Office financial values and calculate profit from worldwide revenue less budget.

#### Matching rule

The legacy NiFi lookup matched TMDB and Box Office records by **title only**, despite the final movie key being `(title, year)`.

To preserve Version 1 behavior, matching must therefore use:

```text
TMDB.title = BoxOffice.title
```

The matching comparison must use trimmed strings. No case folding, punctuation removal, accent normalization, fuzzy matching, or year condition may be introduced in Version 1, because each would change legacy semantics.

The Box Office source has already been deduplicated by `(title, year)`, but title-only lookup can still be ambiguous if the same title occurs in multiple years. The old CSV lookup service ignored duplicates. The dbt migration must make that formerly implicit behavior deterministic:

1. Rank Box Office candidates for each title by ascending `year`.
2. Select the first candidate.
3. Record all titles with more than one Box Office candidate in an audit model.
4. Do not silently add a year-based matching rule in Version 1.

This deterministic rule is a migration safeguard, not a claim that the original lookup handled repeated titles correctly.

#### Movie deduplication rule

The final primary key is `(title, year)`. More than one TMDB `movieid` can theoretically produce the same final natural key.

The model must use a deterministic `row_number()` selection before materializing `global.movies`:

```text
partition by title, year
order by movieid ascending
```

The selected record becomes the published movie. Any non-selected records must be written to an audit model with a reason such as `duplicate_target_movie_key`.

### 3.3 `global.actors`

`global.actors` contains actor biographical attributes sourced from IMDb people data.

| Target column | Type | Nullability | Derivation |
|---|---|---|---|
| `actorname` | `VARCHAR` | Not null | IMDb `primaryName` |
| `birthyear` | `INTEGER` | Nullable | Safely cast IMDb `birthYear` |
| `deathyear` | `INTEGER` | Nullable | Safely cast IMDb `deathYear` |

The actor identity rule remains the legacy Unique Name Assumption: one final row exists for each `actorname`, even though IMDb's stable identifier is `nconst`.

Eligible actor rows must have:

- a non-null `actorname`; and
- at least one of `birthyear` or `deathyear` populated.

If several IMDb people have the same `actorname`, select a single deterministic record using:

```text
partition by actorname
order by
    birthyear is null asc,
    deathyear is null asc,
    birthyear asc nulls last,
    deathyear asc nulls last,
    imdb_person_id asc
```

This rule prefers the most complete biographical record, then ensures repeatable output. All discarded same-name candidates must be visible in an audit model.

### 3.4 `global.genres`

`global.genres` is a lookup relation built from flattened TMDB genre data.

| Target column | Type | Nullability | Derivation |
|---|---|---|---|
| `genrename` | `VARCHAR` | Not null | Distinct non-null TMDB genre names |

A genre enters this table when it appears in at least one valid flattened TMDB genre record. Its name is trimmed before deduplication.

### 3.5 `global.movieactors`

`global.movieactors` links final movies to actors.

| Target column | Type | Nullability | Derivation |
|---|---|---|---|
| `title` | `VARCHAR` | Not null | Resolved from `global.movies` |
| `year` | `INTEGER` | Not null | Resolved from `global.movies` |
| `actorname` | `VARCHAR` | Not null | TMDB cast actor name, matched to `global.actors` |

A bridge row is eligible only when all of the following are true:

1. The flattened TMDB cast row has non-null `movieid` and `actorname`.
2. Its `movieid` resolves to a published `global.movies` record through `global.movies.tmdbid`.
3. Its `actorname` exists in `global.actors`.

The last condition intentionally excludes cast members absent from the IMDb-derived actor dimension. This preserves the legacy integration logic and guarantees that the bridge table obeys its actor foreign key.

Duplicates are removed on `(title, year, actorname)`.

### 3.6 `global.moviegenres`

`global.moviegenres` links final movies to genres.

| Target column | Type | Nullability | Derivation |
|---|---|---|---|
| `title` | `VARCHAR` | Not null | Resolved from `global.movies` |
| `year` | `INTEGER` | Not null | Resolved from `global.movies` |
| `genrename` | `VARCHAR` | Not null | Flattened TMDB genre name, matched to `global.genres` |

A bridge row is eligible only when its source `movieid` resolves to a published `global.movies` record and its `genrename` exists in `global.genres`.

Duplicates are removed on `(title, year, genrename)`.

### 3.7 Semantic Rules

The following rules define valid published target data:

| Rule ID | Relation | Rule |
|---|---|---|
| `BR-01` | Movies | `(title, year)` is unique and both values are non-null |
| `BR-02` | Movies | `profit = revenueworldwide - budget` when both inputs are non-null |
| `BR-03` | Movies | `profit` is null when either `revenueworldwide` or `budget` is null |
| `BR-04` | Movies | `voteaverage` is null or between 0 and 10 inclusive |
| `BR-05` | Actors | `actorname` is unique and non-null |
| `BR-06` | Actors | When both are populated, `deathyear > birthyear` |
| `BR-07` | Genres | `genrename` is unique and non-null |
| `BR-08` | MovieActors | Every row references an existing movie and actor |
| `BR-09` | MovieGenres | Every row references an existing movie and genre |

## 4. Source-to-Target Mapping

### 4.1 Mapping Architecture

The dbt implementation is divided into three transformation layers:

| Layer | Naming convention | Responsibility |
|---|---|---|
| Staging | `stg_*` | Read raw files, standardize names and types, apply source-level cleaning |
| Intermediate | `int_*` | Parse JSON, reconcile sources, apply eligibility rules, resolve ambiguity |
| Global | `global_*` | Publish final relational entities and bridge tables |

The preprocessing from the original notebook belongs in staging and intermediate models. Raw files remain unchanged, and no normalized `.Global/` files are created or required.

### 4.2 Raw File Models

DuckDB reads the raw source files directly. The raw relation names below are logical dbt source names; their physical paths are configured centrally.

| dbt source relation | Raw input | Reader requirements |
|---|---|---|
| `raw.boxoffice_movies` | Box Office CSV | Header enabled; CSV parsing; preserve fields as strings initially where necessary |
| `raw.tmdb_movies` | TMDB movies CSV | Header enabled; preserve `genres` as JSON text |
| `raw.tmdb_credits` | TMDB credits CSV | Header enabled; preserve `cast` as JSON text |
| `raw.imdb_people` | IMDb `name.basics.tsv` | Tab delimiter; header enabled; interpret `\N` as null |

### 4.3 Box Office Staging Mapping

Model: `stg_boxoffice_movies`

| Output column | Source expression or rule |
|---|---|
| `title` | `trim("Release Group")` |
| `year` | Safe cast of `Year` to `INTEGER` |
| `revenueworldwide` | Remove commas from `Worldwide`, then safe cast to `BIGINT` |
| `revenuedomestic` | Remove commas from `Domestic`, then safe cast to `BIGINT` |
| `revenueforeign` | Remove commas from `Foreign`, then safe cast to `BIGINT` |

Filtering and deduplication:

1. Discard rows with null `title` or null `year`.
2. Retain one row per `(title, year)`.
3. If duplicates exist, use the earliest raw input order where available; otherwise use a deterministic ordering on the financial columns and record the duplicates in `audit_boxoffice_duplicate_keys`.
4. Do not use Box Office fields such as rank, genre, rating, vote count, language, or production countries in Version 1.

### 4.4 TMDB Movie Staging Mapping

Model: `stg_tmdb_movies`

| Output column | Source expression or rule |
|---|---|
| `movieid` | Safe cast of `id` to `INTEGER` |
| `title` | `trim(title)` |
| `releasedate` | Safe cast of `release_date` to `DATE` |
| `year` | `year(releasedate)` |
| `budget` | Safe cast of `budget` to `BIGINT` |
| `revenue` | Safe cast of `revenue` to `BIGINT` |
| `votecount` | Safe cast of `vote_count` to `INTEGER` |
| `voteaverage` | Safe cast of `vote_average` to `DECIMAL(3,1)` |
| `genres_json` | Raw `genres` JSON string |

Filtering and deduplication:

1. Discard rows with null `movieid`.
2. Retain one row per `movieid`.
3. Preserve rows with null `year` in staging for auditability.
4. Exclude rows with null `title` or null `year` only when building the movie-publication intermediate model.
5. Do not interpret numeric zero as null unless the source value itself is null or invalid; zero budget and zero revenue are retained as legitimate source values.

### 4.5 TMDB Genre Expansion

Model: `int_tmdb_movie_genres`

The model parses `stg_tmdb_movies.genres_json` as a JSON array and emits one row per array element.

| Output column | Rule |
|---|---|
| `movieid` | `stg_tmdb_movies.movieid` |
| `genrename` | Trim the JSON object's `name` value |

Filtering and deduplication:

1. Invalid JSON, null JSON, empty arrays, null genre names, and blank genre names produce no published bridge row.
2. Retain one row per `(movieid, genrename)`.
3. Invalid JSON records must be captured in `audit_tmdb_invalid_genres_json`.

### 4.6 TMDB Cast Expansion

Model: `int_tmdb_movie_actors`

The model parses `raw.tmdb_credits.cast` as a JSON array and emits one row per cast member.

| Output column | Rule |
|---|---|
| `movieid` | Safe cast of raw `movie_id` to `INTEGER` |
| `actorname` | Trim the JSON object's `name` value |

Filtering and deduplication:

1. Discard rows with null `movieid`, null `actorname`, or blank `actorname`.
2. Retain one row per `(movieid, actorname)`.
3. Ignore `crew` in Version 1.
4. Invalid cast JSON must be captured in `audit_tmdb_invalid_cast_json`.

### 4.7 IMDb People Staging Mapping

Model: `stg_imdb_people`

| Output column | Source expression or rule |
|---|---|
| `imdb_person_id` | `nconst` |
| `actorname` | `trim(primaryName)` |
| `birthyear` | Treat `\N` as null, then safe cast `birthYear` to `INTEGER` |
| `deathyear` | Treat `\N` as null, then safe cast `deathYear` to `INTEGER` |

The actor-publication intermediate model applies the following eligibility condition:

```text
actorname is not null
and trim(actorname) <> ''
and (birthyear is not null or deathyear is not null)
```

Rows that fail this condition must be available in an audit model rather than silently lost.

### 4.8 Movie Reconciliation Mapping

Model: `int_reconciled_movies`

The model starts with eligible TMDB movies, then left joins the deterministic Box Office title lookup.

```text
eligible TMDB movies
LEFT JOIN one Box Office lookup row per title
  ON tmdb.title = boxoffice.title
```

Column-level reconciliation is:

| Final candidate column | Rule |
|---|---|
| `title` | TMDB `title` |
| `year` | TMDB `year` |
| `tmdbid` | TMDB `movieid` |
| `votecount` | TMDB `votecount` |
| `voteaverage` | TMDB `voteaverage` |
| `budget` | TMDB `budget` |
| `revenueworldwide` | `coalesce(boxoffice.revenueworldwide, tmdb.revenue)` |
| `revenuedomestic` | Box Office `revenuedomestic` |
| `profit` | `revenueworldwide - budget` when both values exist; otherwise `NULL` |

This model must preserve a diagnostic field such as `financial_source` with values `boxoffice` or `tmdb`, although that field is not exposed in `global.movies`.

### 4.9 Entity and Bridge Mappings

| Final model | Source intermediate relations | Join and filter rule |
|---|---|---|
| `global_movies` | `int_reconciled_movies` | Publish one deterministic record per `(title, year)` |
| `global_actors` | Eligible IMDb people records | Publish one deterministic record per `actorname` |
| `global_genres` | `int_tmdb_movie_genres` | Publish distinct non-null `genrename` values |
| `global_movieactors` | `int_tmdb_movie_actors`, `global_movies`, `global_actors` | Inner join actor rows to movies on `movieid = tmdbid`, then inner join actors on exact `actorname` |
| `global_moviegenres` | `int_tmdb_movie_genres`, `global_movies`, `global_genres` | Inner join genre rows to movies on `movieid = tmdbid`, then inner join genres on exact `genrename` |

### 4.10 Exclusions and Auditability

The legacy flow frequently discarded records through unmatched routes, invalid-record routes, or database constraints. The dbt migration must retain that behavior for final tables while making the reason observable.

At minimum, create these audit models:

| Audit model | Records captured |
|---|---|
| `audit_tmdb_movies_missing_target_key` | TMDB movie records with missing title or derived year |
| `audit_boxoffice_duplicate_titles` | Box Office titles associated with multiple source rows after staging |
| `audit_duplicate_global_movie_keys` | Reconciled TMDB movie candidates removed because `(title, year)` is duplicated |
| `audit_duplicate_actor_names` | IMDb person records removed by the Unique Name Assumption |
| `audit_tmdb_invalid_genres_json` | TMDB genre values that cannot be parsed as expected |
| `audit_tmdb_invalid_cast_json` | TMDB cast values that cannot be parsed as expected |
| `audit_movieactors_missing_actor` | TMDB cast rows whose actor name does not exist in `global.actors` |
| `audit_movieactors_missing_movie` | TMDB cast rows whose `movieid` does not exist in `global.movies` |
| `audit_moviegenres_missing_movie` | TMDB genre rows whose `movieid` does not exist in `global.movies` |

Audit models are diagnostic outputs. They do not replace dbt tests and do not appear in the final `global` schema.