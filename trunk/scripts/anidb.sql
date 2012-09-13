-- anidb.sql: anidb database schema
--
-- Copyright (C) 2006,2009  Tristan Willy <tristan.willy at gmail.com>
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
-- Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

-- Drop old data
DROP TABLE anime;
DROP TABLE titles;
DROP TABLE genre_names;
DROP TABLE genre;
DROP TABLE details_cache;
DROP TABLE search_cache_table;
DROP TABLE search_hits;
DROP VIEW  search_cache;
VACUUM;

-- Data
CREATE TABLE anime (
  aid INTEGER PRIMARY KEY,
  type varchar(1024),
  numeps INTEGER,
  rating REAL,
  startdate date,
  enddate date,
  url varchar(1024)
);
CREATE TABLE titles (
  aid int REFERENCES anime(aid),
  title varchar(1024)
);
CREATE TABLE genre_names (
  gid AUTOINCREMENT,
  gname varchar(1024) UNIQUE
);
CREATE TABLE genre (
  aid int REFERENCES anime(aid),
  gid int REFERENCES genre_names(gid)
);

-- Metadata
CREATE TABLE details_cache (
  aid int PRIMARY KEY REFERENCES anime(aid),
  last_refreshed int
);
CREATE TABLE search_cache_table (
    sid AUTOINCREMENT,
    terms varchar(1024) UNIQUE,
    last_refreshed DATE
);
CREATE TABLE search_hits (
    sid int REFERENCES search_cache_table(sid),
    id_num int CHECK (id_num >= 0),
    title varchar(1024)
);

-- Use this to inspect the search cache
CREATE VIEW search_cache AS
  SELECT * FROM search_cache_table
    WHERE (last_refreshed + 30) > julianday('now');
