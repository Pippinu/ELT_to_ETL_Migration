## Movie Analytics

This is a movie analytics data warehouse. Beside the real implementation,I'll focus mostly on the dimensional fact model and the star schema, plus how the OLAP queries exercise both.

I implemented this analytics project starting from an ELT pipeline where i used dbt plus DuckDB rather than classic ETL and Postgres.

### ETL→ELT + Sources — 1 min
Quickly on architecture: dbt gives declarative, version-controlled SQL transformations instead of an opaque visual NiFi flow — same reconciliation step, just testable and diffable. 

**Three sources** feed it: 
- TMDB for metadata and nested JSON credits, 
- Box Office for flat CSV revenue, 
- IMDb for a large TSV of person biographical data.

None share an identifier, which is really the whole integration problem in one sentence.

### Integration Highlights — 1 min

Four things solve that: 
- fuzzy title matching between TMDB and Box Office on a 0-to-4 score.
- exact title-plus-year down to substring match with deterministic tie-breaking via a window function; 
- exact name matching for people against IMDb; 
- a source-priority rule where Box Office wins over TMDB when both agree on a movie; 
- a whitelist restricting crew to the roles that actually matter for analysis — Director, Writer, Producer, and a few others. 

I won't dwell here — this is plumbing, not the graded design.

### DFM — 2.5 min, the core
Here's the DFM. Two facts, not one, because they answer different questions at different grains: Movie Performance is one row per movie — how did it do — and Movie Credit is one row per credit occurrence — who worked on what. 
Forcing those into a single fact would mean picking a grain that's wrong for one of the two.

Conformance is asymmetric on purpose. 
- ***Date*** and ***Movie*** are genuinely conformed — same surrogate key reused in both facts, which is what lets me drill across and ask something like 'a director's average profit' by joining both facts through Movie. 
- ***Person*** and ***Credit Role*** stay **local** to Movie Credit, because they have no meaning in Performance — conforming them would be conformance for its own sake.

Movie Credit itself is a **factless fact**, deliberately — there's no natural numeric measure for 'this credit occurred,' the occurrence is the information, so I use COUNT at query time rather than inventing one.

And additivity drove the measure design directly: ***vote_avg*** and ***roi_ratio*** are **non-additive** ratios, so rather than leaving that as a trap, I carry vote_count and weighted_score as explicit **support measures** — every query recomputes the aggregate ratio from its components instead of naively averaging an average.

### Star Schema — 2 min
Translating that to the logical layer, four decisions matter more than the diagram itself.

1. It's a **pure star**, not a snowflake. Snowflaking pays off with high secondary-to-primary cardinality or a hierarchy shared across dimensions; neither applies to job and department, which have a handful of values each, so dim_credit_role stays flat.

2. For the ***movie-genre*** many-to-many, I used a **bridge table** over push-down specifically to protect the fact's grain — push-down would replicate Performance rows per genre and break the one-row-per-movie guarantee I test with row-count parity against dim_movie.

3. ***fct_movie_performance*** is a primary fact, not a view, even though it holds derived measures like profit and ROI — those are computed from same-row columns at load time, not aggregated up from something finer-grained.

4. And budget_tier is technically a descriptive attribute, functionally determined by budget rather than an independent dimension — but I use it for roll-up anyway, a deliberate, practical bend of the strict distinction.

### Integrity Constraints + dbt Tests — 1 min
All of that is backed by explicit constraints — functional dependencies, domain restrictions, fact identification, one semantic rule on birth and death year — and dbt turns every one of them into an **automated test**: `not_null` and `unique` for structure, `accepted_values` for domain, `unique_combination_of_columns` for composite identity, `relationships` for referential integrity, and `expression_is_true` for business rules like worldwide equalling domestic plus international. Every dbt build re-verifies all of this.

### OLAP — 1.5 min
On the query side, I implemented every classic OLAP operator against this schema. 
- Roll-up aggregating date up to decade. 
- Drill-down adding genre on top of decade to go from ROI-by-decade to ROI-by-decade-and-genre. 
- Slice and dice — a single-genre filter, and a person-plus-decade filter. 
- Pivot, rotating budget tier into columns to show tier coexistence by year. 
- And drill-across, joining Movie Credit and Movie Performance through the conformed Movie key — that's the director-actor collaboration query, and it only works because Movie is conformed, which is exactly the design decision from the DFM slide paying off here.

### Summary — 30s
So: 
- three heterogeneous sources into one schema via DFM-driven design; 
- two facts at genuinely different grains sharing conformed dimensions only where that serves a real analytical need; 
- a pure star driven by cardinality rather than convention; 
- and OLAP queries that exercise every operator against that design.