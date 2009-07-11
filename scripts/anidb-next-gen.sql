-- anidb.sql:
--   anidb database crap, now with less modular!
--
-- Copyright (C) 2006-2009  Tristan Willy  <tristan.willy at gmail.com>
-- Copyright (C) 2009  Justin "The Dean" Lee  <kool.name at gmail.com>
--
-- This program is free software; you can redistribute it and/or
-- modify it under the terms of the GNU General Public License version 2
-- as published by the Free Software Foundation.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program; if not, write to the Free Software
-- Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
-- USA.


--
-- house keeping

DROP TABLE IF EXISTS anime;

DROP TABLE IF EXISTS titles;
DROP TABLE IF EXISTS shortnames;
DROP TABLE IF EXISTS synonyms;
DROP TABLE IF EXISTS resources;

DROP TABLE IF EXISTS tag;
DROP TABLE IF EXISTS tags;
DROP TABLE IF EXISTS category;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS creator;
DROP TABLE IF EXISTS creators;

DROP TABLE IF EXISTS results;
DROP TABLE IF EXISTS query;

DROP TABLE IF EXISTS config;

DROP VIEW IF EXISTS animes;
DROP VIEW IF EXISTS queries;

DROP TRIGGER IF EXISTS refresh_animes;
DROP TRIGGER IF EXISTS refresh_queries;


--
-- data tables

-- you win, pc486
CREATE TABLE anime (
  -- ident
  aid INTEGER PRIMARY KEY NOT NULL,
  title TEXT(1024) NOT NULL,
  got DATE DEFAULT (julianday('now')),

  -- info
  type TEXT(1024) DEFAULT NULL,
  length INTEGER DEFAULT NULL,
  rating REAL DEFAULT NULL,
  tmprating REAL DEFAULT NULL,
  start DATE DEFAULT NULL,
  end DATE DEFAULT NULL
);

CREATE TABLE query (
  qid INTEGER PRIMARY KEY AUTOINCREMENT,
  term TEXT(1024) UNIQUE,
  got DATE DEFAULT (julianday('now'))
);

CREATE TABLE results (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  qid INTEGER REFERENCES queries(qid),
  title TEXT(1024),
  aid INTEGER REFERENCES anime(aid)
);

CREATE TABLE creator (
  pid INTEGER PRIMARY KEY,
  type TEXT(1024) DEFAULT NULL,
  title TEXT(1024)
);

CREATE TABLE creators (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  pid INTEGER REFERENCES creator(pid),
  aid INTEGER REFERENCES anime(aid)
);

CREATE TABLE tag (
  tid INTEGER PRIMARY KEY,
  tag TEXT(1024),
  description TEXT(1024) DEFAULT NULL -- reserved for later
);

CREATE TABLE tags (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tid INTEGER REFERENCES tag(tid),
  aid INTEGER REFERENCES anime(aid)
);

CREATE TABLE category (
  cid INTEGER PRIMARY KEY,
  category TEXT(1024),
  description TEXT(1024) DEFAULT NULL -- reserved for later
);

CREATE TABLE categories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  cid INTEGER REFERENCES categories(cid),
  aid INTEGER REFERENCES anime(aid)
);

CREATE TABLE titles (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT(1024) UNIQUE ON CONFLICT REPLACE,
  state INTEGER DEFAULT 0,
  type TEXT(1024),
  aid INTEGER REFERENCES anime(aid)
);

CREATE TABLE synonyms (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  synonym TEXT(1024) UNIQUE ON CONFLICT REPLACE,
  aid INTEGER REFERENCES anime(aid)
);

CREATE TABLE shortnames (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  shortname TEXT(1024) UNIQUE ON CONFLICT REPLACE,
  aid INTEGER REFERENCES anime(aid)
);

CREATE TABLE resources (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT(1024) NOT NULL ON CONFLICT IGNORE,
  link TEXT(1024) NOT NULL ON CONFLICT IGNORE,
  aid INTEGER REFERENCES anime(aid)
);


--
-- Meta crap

CREATE TABLE config (
  name TEXT(1024) PRIMARY KEY NOT NULL,
  value BLOB(1024)
);

-- 30 day timeout on scraped data
INSERT INTO config VALUES('anime_refresh', 30);

-- 10 day timeout on queries
INSERT INTO config VALUES('query_refresh', 10);


--
-- Management stuff! :D

-- these next two are for quickly checking the DB for valid anime/query info
CREATE VIEW animes AS
  SELECT * FROM anime
    WHERE
      (got + (SELECT value FROM config WHERE name = 'anime_refresh'))
        >
      julianday('now');

CREATE VIEW queries AS
  SELECT * FROM query
    WHERE
      (got + (SELECT value FROM config WHERE name = 'query_refresh'))
        >
      julianday('now');

-- trigger for purging expired anime info!
CREATE TRIGGER purge_animes
  INSTEAD OF DELETE ON animes
    BEGIN
      DELETE FROM anime
        WHERE
          (got + (SELECT value FROM config WHERE name = 'anime_refresh') - 1)
            <
          julianday('now');
      -- This section could possibly be sped up?
      DELETE FROM creators
        WHERE
          NOT EXISTS (SELECT * FROM anime WHERE anime.aid = creators.aid);
      DELETE FROM tags
        WHERE
          NOT EXISTS (SELECT * FROM anime WHERE anime.aid = tags.aid);
      DELETE FROM categories
        WHERE
          NOT EXISTS (SELECT * FROM anime WHERE anime.aid = categories.aid);
      DELETE FROM titles
        WHERE
          NOT EXISTS (SELECT * FROM anime WHERE anime.aid = titles.aid);
      DELETE FROM shortnames
        WHERE
          NOT EXISTS (SELECT * FROM anime WHERE anime.aid = shortnames.aid);
      DELETE FROM synonyms
        WHERE
          NOT EXISTS (SELECT * FROM anime WHERE anime.aid = synonyms.aid);
      DELETE FROM resources
        WHERE
          NOT EXISTS (SELECT * FROM anime WHERE anime.aid = resources.aid);
    END;

-- trigger for purging expired queries
CREATE TRIGGER purge_queries
  INSTEAD OF DELETE ON queries
    BEGIN
      DELETE FROM query
        WHERE
          (got + (SELECT value FROM config WHERE name = 'query_refresh') - 1)
            <
          julianday('now');
      DELETE FROM results
        WHERE
          NOT EXISTS (SELECT * FROM query WHERE query.qid = results.qid);
    END;