-- jedict.sql: jedict database schema
-- Copyright (C) 2006  Andreas Högström <superjojo at gmail.com>
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

DROP SCHEMA jedict CASCADE;
CREATE SCHEMA jedict;
SET search_path TO jedict;

DROP TABLE jedict_main CASCADE;

CREATE TABLE jedict_main (
	kanji varchar(512),
	kana varchar(512),
	english varchar(1024)
);

CREATE INDEX jedict_kana_index ON jedict_main (kana);
