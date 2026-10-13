# Context handoff: Data Management exam project (DW / DFM / star schema / dbt + DuckDB)

## Your role in this session
You're my coach for the oral discussion of my Data Warehouse exam project, and my reference for dbt, DuckDB, DFM (Golfarelli & Rizzi), Kimball and data warehousing in general. I'll load the whole repo and the professor's lecture slides (DataWarehousing.pdf, derived from G&R "Data Warehouse Design") in this session.

**Before answering anything:** read the repo (`movie_analytics/models`, `analyses`, `_marts__models.yml`, `varie/StarSchema.dbml`, `varie/project_current_state.txt`, `docs/migration_spec.md`) and the lecture PDF. Then summarize your understanding in at most 10 lines and ask which task I want first.

## How I want you to work
- Concise, direct, bullet points and short sections. Still complete, just scannable.
- Check claims against the actual files and slides before asserting them. Say so when you can't verify something.
- Give theory first (G&R, plus Kimball where relevant), then evaluate my implementation against it.
- Tell me when I'm wrong or a choice is weak. I need defensible answers, not flattery.

## About me
- Student (NLP/ML focus). The exam deliverable is a DW project: integrate sources, DFM, star/snowflake schema on a relational DB, OLAP queries. The professor approved ELT (dbt) instead of ETL, and DuckDB instead of Postgres.
- I'm a junior cloud data engineer (AWS/Snowflake), so Kimball's *Data Warehouse Toolkit* is useful, but G&R vocabulary is what's graded.
- I'm starting a thesis on dbt: using the lineage graph to balance virtualized vs materialized models.

## Project snapshot
- Repo: github.com/Pippinu/ELT_to_ETL_Migration, dbt project in `movie_analytics/`.
- Sources: TMDB movies + credits (nested JSON), Box Office CSV, IMDb `name.basics` TSV. No shared IDs.
- dbt layers: staging (views) → intermediate (views) → marts (tables) in DuckDB.
- Intermediate models:
  - `int_movie_matching`: fuzzy TMDB↔BoxOffice join, ±1 year tolerance, 0–4 `match_score`, then `QUALIFY ROW_NUMBER() OVER (PARTITION BY tmdb_movie_id ORDER BY match_score DESC, boxoffice_release_year DESC) = 1`.
  - `int_person_matching`: exact-name match to IMDb, deterministic dedup.
  - `int_merged_movie`: Box Office > TMDB revenue via coalesce, 0 → NULL.
  - `int_credits_union`: cast + whitelisted crew (Director, Writer, Producer, Executive Producer, Director of Photography, Original Music Composer). Cast rows get job='Actor'.
- Marts (star schema):
  - Dimensions: `dim_date` (1900–2050 spine), `dim_movie` (carries `release_date`, `budget_usd`, derived `budget_tier`), `dim_person`, `dim_genre`, `dim_credit_role` (flat: credit_type/job/department).
  - Bridge: `bridge_movie_genre` (full attribution, no weight).
  - Facts: `fct_movie_performance` (PK `movie_key`, grain 1 row/movie, measures with `_usd` suffix, `vote_avg`, `weighted_score`, `roi_ratio`), and `fct_movie_credit` (factless, PK `(movie_key, person_key, credit_role_key)`, `release_date_key` is an FK but not part of the PK).
- Verified locally: `dbt build` and tests pass with 1 expected warning (`dim_person` birth_year > death_year, 3 rows, `severity: warn`). All OLAP queries in `analyses/` ran correctly.
- OLAP files: `revenue_by_decade`, `movie_performance_by_budget_tier`, `roi_over_decade_and_genre`, `sci-fi_revenue_by_decade`, `total_revenue_scorsese_2010`, `top_actors_movies_decade`, `top_gross_top_rated_genre_decade`, `top_worst_5_genre_decade`, `top_directors_by_avg_profit`, `best_director_actor_duo` (now joins job='Actor'), and the pivot `movies_per_budget_size`.

## The deck (15 slides, sent to the professor as a pre-read; discussion is 10–15 min including questions)
1. Title
2. Project overview
3. ETL→ELT migration plus three-layer architecture (source → virtual reconciled layer = staging+intermediate views → DW = marts tables)
4. Data sources
5. Integration highlights (fuzzy match, person match, revenue reconciliation, crew whitelist)
6. DFM text
7. DFM diagram + measure dictionary
8. Star schema text
9. Star schema diagram (rendered from the DBML)
10. Integrity constraints
11. "dbt tests replace relational constraints" (5 test categories)
12. Query engine: ROLAP with columnar execution
13. OLAP query examples: Q1 `roi_over_decade_and_genre`, Q2 pivot, Q3 `best_director_actor_duo`
14. OLAP operators table
15. Summary

Emphasis: DFM, star schema and OLAP are the core. ELT/dbt is secondary context.

## Design decisions and rationale (the reasoning I must be able to defend)
- **Two facts.** Different business questions and grains (1 row/movie vs 1 row/credit occurrence). One fact would force a wrong grain for one of them.
- **Asymmetric conformance, by design.** Date and Movie are conformed (same surrogate keys in both facts, which enables drill-across). Person and Credit Role are local to Movie Credit.
- **Movie Credit is factless** (G&R empty fact schema). Analysis uses COUNT.
- **Additivity.** `vote_avg` and `roi_ratio` are non-additive. `vote_count` and `weighted_score` are support measures. Queries recompute `SUM(weighted_score)/SUM(vote_count)` and `SUM(profit)/SUM(budget)`.
- **Pure star, not snowflake.**
  - `dim_credit_role`: the cardinality-ratio trigger doesn't apply (handful of jobs/departments).
  - `dim_date`: the ratio technically fires (~55k rows vs 16 decades), but the saving is negligible and it's the most-queried dimension.
  - Shared-hierarchy trigger: not applicable. Conformance (one dimension, many facts) is not a shared hierarchy (one hierarchy fragment, many dimensions).
- **Movie–Genre M:N → bridge table, not push-down.** Push-down would replicate fact rows per genre. That breaks the grain, the `equal_rowcount` test against `dim_movie`, and double-counts revenue. A bridge is DFM's "multiple arc", a different construct from snowflaking.
- **`fct_movie_performance` is a primary fact, not a G&R "view".** Derived ≠ aggregated: its derived measures are computed from same-row columns.
- **`budget_tier`** is functionally determined by budget, so strictly a descriptive attribute, but used for roll-up. Deliberate bend. `budget_usd` is stored in both `dim_movie` (to derive the tier) and the fact (as a measure).
- **Architecture.** Three-layer with a *virtual* reconciled layer (dbt views). ROLAP on a columnar, vectorized, in-process engine (same category as Snowflake). No materialized aggregate views (unneeded at this volume).
- **Not addressed, to be framed as honest scope limits:** scalability (single-node DuckDB) and security (no RBAC). Extensibility and administerability are partly covered (modular dbt layers, dbt docs/tests).
- **OLAP classification (judgment calls to defend):**
  - Roll-up: `revenue_by_decade`, `movie_performance_by_budget_tier`.
  - Drill-down (also roll-up): `roi_over_decade_and_genre`.
  - Slice: `sci-fi_revenue_by_decade`.
  - Dice: `total_revenue_scorsese_2010`, `top_actors_movies_decade`, `top_gross_top_rated_genre_decade`. The last two use `QUALIFY ROW_NUMBER()=1`, treated as dice because "ranking" isn't a G&R operator.
  - Pivot: `movies_per_budget_size` (the PIVOT clause is the operator; the WHERE after it is an ordinary filter).
  - Drill-across: `best_director_actor_duo`, `top_directors_by_avg_profit`.

## Caveats from the previous session (please re-verify)
- **Slide-number citations to the professor's PDF** (e.g. "slide 23", "99–100", "126–127", "149–152") and the claim that his taxonomy has exactly six operators were **never checked against the PDF**. Verify each against the real slides before I quote any of them.
- The "Plato/Plautus BC-era" explanation for the 3 `dim_person` rows is a **hypothesis**. The rows were 850/800, 427/347 and 254/184. Query `person_name` before I claim it in the talk.
- The 10-minute speech draft from the previous session predates slides 3 (three-layer), 12 (ROLAP) and the new Q2/Q3 wording. It must be rewritten.

## Tasks, in order
1. **Speech:** write a 10-minute spoken script matching the final 15 slides, with approximate timing per slide. Put roughly 60% of the time on slides 6–9 and 12–14 (DFM, star schema, OLAP) and keep ELT/dbt brief. Natural spoken English, no slide-reading.
2. **Mock Q&A:** act as a skeptical DW professor. Ask one question at a time on DFM, star vs snowflake, bridge vs push-down, conformance, factless facts, additivity, ROLAP/MOLAP, three-layer architecture, fuzzy matching, dbt tests. Wait for my answer, then grade it and give a model answer.
3. **Reference mode:** answer my dbt, DuckDB, DFM, Kimball and Snowflake questions. For each, show the G&R view, the Kimball view, and how my project compares.