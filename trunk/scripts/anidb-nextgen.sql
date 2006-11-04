-- anidb-nextgen.sql: anidb database schema
--
-- Copyright (C) 2006   Tristan Willy <tristan.willy at gmail.com>
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

-- AniDB is claims the "anidb" schema
DROP SCHEMA anidb CASCADE;
CREATE SCHEMA anidb;
SET search_path TO anidb;

-- Data
CREATE TABLE anime (
	aid int PRIMARY KEY,
	type varchar(32),
	numeps int,
	rating real,
	startdate date,
	enddate date,
	url varchar(1024)
);
CREATE TABLE titles (
	aid int REFERENCES anime(aid),
	title varchar(256)
);
CREATE TABLE genre_names (
	gid SERIAL PRIMARY KEY,
	gname varchar(64)
);
CREATE TABLE genre (
	aid int REFERENCES anime(aid),
	gid int REFERENCES genre_names(gid)
);

-- Metadata
CREATE TABLE details_cache (
	aid int PRIMARY KEY REFERENCES anime(aid),
	last_refreshed timestamp
);
CREATE TABLE search_cache_table (
  sid SERIAL UNIQUE,
  terms varchar(256) PRIMARY KEY,
  last_refreshed timestamp
);
CREATE TABLE search_hits (
  sid int REFERENCES search_cache_table(sid),
  id_num int CHECK (id_num >= 0),
  title varchar(256)
);

-- Use this to inspect the search cache
CREATE VIEW search_cache AS
  SELECT * FROM search_cache_table
    WHERE age(current_timestamp, last_refreshed) < interval '1 month';
