--
-- PostgreSQL database dump
--

\restrict T8yAXvpKXvoE1UDRIJRmhROjUu1Gx9nA3YQmegSuABzY9bydbDFJkJbCal8D9cQ

-- Dumped from database version 16.10 (Ubuntu 16.10-0ubuntu0.24.04.1)
-- Dumped by pg_dump version 16.10 (Ubuntu 16.10-0ubuntu0.24.04.1)

-- Started on 2025-12-03 18:02:06 CET

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 8 (class 2615 OID 16406)
-- Name: global; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA global;


ALTER SCHEMA global OWNER TO postgres;

--
-- TOC entry 7 (class 2615 OID 16405)
-- Name: integration; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA integration;


ALTER SCHEMA integration OWNER TO postgres;

--
-- TOC entry 6 (class 2615 OID 16404)
-- Name: staging; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA staging;


ALTER SCHEMA staging OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 218 (class 1259 OID 16466)
-- Name: actors; Type: TABLE; Schema: global; Owner: postgres
--

CREATE TABLE global.actors (
    actor_name text NOT NULL,
    birth_year integer,
    death_year integer
);


ALTER TABLE global.actors OWNER TO postgres;

--
-- TOC entry 220 (class 1259 OID 16480)
-- Name: genres; Type: TABLE; Schema: global; Owner: postgres
--

CREATE TABLE global.genres (
    genre_name text NOT NULL
);


ALTER TABLE global.genres OWNER TO postgres;

--
-- TOC entry 221 (class 1259 OID 16487)
-- Name: movie_actors; Type: TABLE; Schema: global; Owner: postgres
--

CREATE TABLE global.movie_actors (
    title text NOT NULL,
    year integer NOT NULL,
    actor_name text NOT NULL
);


ALTER TABLE global.movie_actors OWNER TO postgres;

--
-- TOC entry 222 (class 1259 OID 16504)
-- Name: movie_genres; Type: TABLE; Schema: global; Owner: postgres
--

CREATE TABLE global.movie_genres (
    title text NOT NULL,
    year integer NOT NULL,
    genre_name text NOT NULL
);


ALTER TABLE global.movie_genres OWNER TO postgres;

--
-- TOC entry 219 (class 1259 OID 16473)
-- Name: movies; Type: TABLE; Schema: global; Owner: postgres
--

CREATE TABLE global.movies (
    title text NOT NULL,
    year integer NOT NULL,
    tmdb_id integer,
    vote_count integer,
    vote_average numeric(3,1),
    budget bigint,
    revenue_worldwide bigint,
    revenue_domestic bigint,
    profit bigint
);


ALTER TABLE global.movies OWNER TO postgres;

--
-- TOC entry 3307 (class 2606 OID 16472)
-- Name: actors actors_pkey; Type: CONSTRAINT; Schema: global; Owner: postgres
--

ALTER TABLE ONLY global.actors
    ADD CONSTRAINT actors_pkey PRIMARY KEY (actor_name);


--
-- TOC entry 3311 (class 2606 OID 16486)
-- Name: genres genres_pkey; Type: CONSTRAINT; Schema: global; Owner: postgres
--

ALTER TABLE ONLY global.genres
    ADD CONSTRAINT genres_pkey PRIMARY KEY (genre_name);


--
-- TOC entry 3313 (class 2606 OID 16493)
-- Name: movie_actors movie_actors_pkey; Type: CONSTRAINT; Schema: global; Owner: postgres
--

ALTER TABLE ONLY global.movie_actors
    ADD CONSTRAINT movie_actors_pkey PRIMARY KEY (title, year, actor_name);


--
-- TOC entry 3315 (class 2606 OID 16510)
-- Name: movie_genres movie_genres_pkey; Type: CONSTRAINT; Schema: global; Owner: postgres
--

ALTER TABLE ONLY global.movie_genres
    ADD CONSTRAINT movie_genres_pkey PRIMARY KEY (title, year, genre_name);


--
-- TOC entry 3309 (class 2606 OID 16479)
-- Name: movies movies_pkey; Type: CONSTRAINT; Schema: global; Owner: postgres
--

ALTER TABLE ONLY global.movies
    ADD CONSTRAINT movies_pkey PRIMARY KEY (title, year);


--
-- TOC entry 3316 (class 2606 OID 16499)
-- Name: movie_actors fk_ma_actor; Type: FK CONSTRAINT; Schema: global; Owner: postgres
--

ALTER TABLE ONLY global.movie_actors
    ADD CONSTRAINT fk_ma_actor FOREIGN KEY (actor_name) REFERENCES global.actors(actor_name);


--
-- TOC entry 3317 (class 2606 OID 16494)
-- Name: movie_actors fk_ma_movie; Type: FK CONSTRAINT; Schema: global; Owner: postgres
--

ALTER TABLE ONLY global.movie_actors
    ADD CONSTRAINT fk_ma_movie FOREIGN KEY (title, year) REFERENCES global.movies(title, year);


--
-- TOC entry 3318 (class 2606 OID 16516)
-- Name: movie_genres fk_mg_genre; Type: FK CONSTRAINT; Schema: global; Owner: postgres
--

ALTER TABLE ONLY global.movie_genres
    ADD CONSTRAINT fk_mg_genre FOREIGN KEY (genre_name) REFERENCES global.genres(genre_name);


--
-- TOC entry 3319 (class 2606 OID 16511)
-- Name: movie_genres fk_mg_movie; Type: FK CONSTRAINT; Schema: global; Owner: postgres
--

ALTER TABLE ONLY global.movie_genres
    ADD CONSTRAINT fk_mg_movie FOREIGN KEY (title, year) REFERENCES global.movies(title, year);


--
-- TOC entry 3468 (class 0 OID 0)
-- Dependencies: 8
-- Name: SCHEMA global; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA global TO nifi_etl;


--
-- TOC entry 3469 (class 0 OID 0)
-- Dependencies: 7
-- Name: SCHEMA integration; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA integration TO nifi_etl;


--
-- TOC entry 3470 (class 0 OID 0)
-- Dependencies: 6
-- Name: SCHEMA staging; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA staging TO nifi_etl;


--
-- TOC entry 3471 (class 0 OID 0)
-- Dependencies: 218
-- Name: TABLE actors; Type: ACL; Schema: global; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE global.actors TO nifi_etl;


--
-- TOC entry 3472 (class 0 OID 0)
-- Dependencies: 220
-- Name: TABLE genres; Type: ACL; Schema: global; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE global.genres TO nifi_etl;


--
-- TOC entry 3473 (class 0 OID 0)
-- Dependencies: 221
-- Name: TABLE movie_actors; Type: ACL; Schema: global; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE global.movie_actors TO nifi_etl;


--
-- TOC entry 3474 (class 0 OID 0)
-- Dependencies: 222
-- Name: TABLE movie_genres; Type: ACL; Schema: global; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE global.movie_genres TO nifi_etl;


--
-- TOC entry 3475 (class 0 OID 0)
-- Dependencies: 219
-- Name: TABLE movies; Type: ACL; Schema: global; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE global.movies TO nifi_etl;


--
-- TOC entry 2058 (class 826 OID 16409)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: global; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA global GRANT SELECT ON TABLES TO nifi_etl;


--
-- TOC entry 2057 (class 826 OID 16408)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: integration; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA integration GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES TO nifi_etl;


--
-- TOC entry 2056 (class 826 OID 16407)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: staging; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA staging GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES TO nifi_etl;


-- Completed on 2025-12-03 18:02:07 CET

--
-- PostgreSQL database dump complete
--

\unrestrict T8yAXvpKXvoE1UDRIJRmhROjUu1Gx9nA3YQmegSuABzY9bydbDFJkJbCal8D9cQ

