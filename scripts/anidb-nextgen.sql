DROP VIEW search_cache;

DROP TABLE search_hits CASCADE;
DROP TABLE search_cache_table CASCADE;
DROP TABLE details_cache CASCADE;
DROP TABLE genre CASCADE;
DROP TABLE titles CASCADE;
DROP TABLE anime CASCADE;
DROP TABLE genre_names CASCADE;

-- Data
CREATE TABLE anime (
	aid int PRIMARY KEY,
	type varchar(8),
	numeps int,
	rating real,
	startdate date,
	enddate date,
	url varchar(256)
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
	last_refreshed date
);
CREATE TABLE search_cache_table (
  sid SERIAL UNIQUE,
  terms varchar(256) PRIMARY KEY,
  last_refreshed date
);
CREATE TABLE search_hits (
  sid int REFERENCES search_cache_table(sid),
  id_num int CHECK (id_num >= 0),
  title varchar(256)
);

-- Use this to inspect the search cache
CREATE VIEW search_cache AS
  SELECT * FROM search_cache_table
    WHERE last_refreshed < interval '1m';

-- Remove old junk from the search cache when we update the table
CREATE RULE search_cache_cleaner
  AS ON INSERT
  TO search_cache_table
  DO ALSO DELETE FROM search_cache_table WHERE last_refreshed >= interval '1m';
