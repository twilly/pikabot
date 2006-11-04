-- animefeed.sql: animefeed rss database schema
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

-- animefeed is claims the "animefeed" schema
DROP SCHEMA animefeed CASCADE;
CREATE SCHEMA animefeed;
SET search_path TO animefeed;

CREATE TABLE items (
  tid SERIAL PRIMARY KEY,
  title VARCHAR(1024) NOT NULL,
  url VARCHAR(2048) UNIQUE NOT NULL,
  stamp TIMESTAMP NOT NULL
);
