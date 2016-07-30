#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use DBIx::Custom;

my $db_path = 'bunko.sqlite3';

my $is_db_exist = 1;
$is_db_exist = 0 unless -f $is_db_exist;

my $dbi = DBIx::Custom->connect(
    dsn    => "dbi:SQLite:dbname=$db_path",
    option => { sqlite_unicode => 1, RaiseError => 1 },
);

if ( ! $is_db_exist )
{
    $dbi->execute(q|PRAGMA foreign_keys = ON|);

    $dbi->execute(q|CREATE TABLE moji_type (type TEXT PRIMARY KEY)|);

    for my $type (qw/旧字旧仮名 旧字新仮名 新字旧仮名 新字新仮名 その他/)
    {
        $dbi->insert({ type => $type }, table => 'moji_type');
    }

    $dbi->execute(q|CREATE TABLE charset (name TEXT PRIMARY KEY)|);

    for my $name ( ('JIS X 0208', '') )
    {
        $dbi->insert({ name => $name }, table => 'charset');
    }

    $dbi->execute(q|CREATE TABLE char_encoding_scheme (encoding_scheme TEXT PRIMARY KEY)|);

    for my $encoding_scheme (qw/ShiftJIS UTF-8 EUC/, ('') )
    {
        $dbi->insert({ encoding_scheme => $encoding_scheme }, table => 'char_encoding_scheme');
    }

    $dbi->execute(q|
        CREATE TABLE work (
            id                         INTEGER  PRIMARY KEY,
            title                      TEXT     NOT NULL  CHECK(title != ''),
            title_yomi                 TEXT     NOT NULL  DEFAULT '',
            title_sort_yomi            TEXT     NOT NULL  DEFAULT '',
            subtitle                   TEXT     NOT NULL  DEFAULT '',
            subtitle_yomi              TEXT     NOT NULL  DEFAULT '',
            original_title             TEXT     NOT NULL  DEFAULT '',
            first_appearance           TEXT     NOT NULL  DEFAULT '',
            moji_type                  TEXT     NOT NULL,
            is_out_of_copyright        INTEGER  NOT NULL  CHECK(is_out_of_copyright == 0 OR is_out_of_copyright == 1),
            aozora_published_date      TEXT     NOT NULL,
            aozora_lastupdate          TEXT     NOT NULL,
            card_url                   TEXT     NOT NULL,
            data_entry_operator        TEXT     NOT NULL  DEFAULT '',
            proofreader                TEXT     NOT NULL  DEFAULT '',
            text_raw_utf8              TEXT     NOT NULL  DEFAULT '',
            text_url                   TEXT     NOT NULL  DEFAULT '',
            text_lastupdate            TEXT     NOT NULL  DEFAULT '',
            text_char_set              TEXT     NOT NULL,
            text_char_encoding_scheme  TEXT     NOT NULL,
            text_revision_cnt          INTEGER  NOT NULL  DEFAULT '',
            html_utf8                  TEXT     NOT NULL  DEFAULT '',
            html_url                   TEXT     NOT NULL  DEFAULT '',
            html_lastupdate            TEXT     NOT NULL  DEFAULT '',
            html_char_set              TEXT     NOT NULL,
            html_char_encoding_scheme  TEXT     NOT NULL,
            html_revision_cnt          INTEGER  NOT NULL  DEFAULT '',
            FOREIGN KEY(moji_type)                  REFERENCES  moji_type(type)                        ON UPDATE CASCADE,
            FOREIGN KEY(text_char_set)              REFERENCES  charset(name)                          ON UPDATE CASCADE,
            FOREIGN KEY(text_char_encoding_scheme)  REFERENCES  char_encoding_scheme(encoding_scheme)  ON UPDATE CASCADE,
            FOREIGN KEY(html_char_set)              REFERENCES  charset(name)                          ON UPDATE CASCADE,
            FOREIGN KEY(html_char_encoding_scheme)  REFERENCES  char_encoding_scheme(encoding_scheme)  ON UPDATE CASCADE
        )
    |);

    $dbi->execute(q|CREATE TABLE valid_ndc (ndc TEXT PRIMARY KEY)|);

    for my $valid_ndc ( 0 .. 999 )
    {
        $valid_ndc = sprintf("%03d", $valid_ndc);
        $dbi->insert({ ndc => $valid_ndc       }, table => 'valid_ndc');
        $dbi->insert({ ndc => 'K' . $valid_ndc }, table => 'valid_ndc'); # 児童書
    }

    $dbi->execute(q|
        CREATE TABLE NDC (
            work_id  INTEGER,
            ndc      TEXT,
            PRIMARY KEY(work_id, ndc),
            FOREIGN KEY(work_id)  REFERENCES  work(id)        ON DELETE CASCADE,
            FOREIGN KEY(ndc)      REFERENCES  valid_ndc(ndc)  ON UPDATE CASCADE
        )
    |);

    $dbi->execute(q|CREATE INDEX ndc_idx ON NDC(ndc)|);

    $dbi->execute(q|
        CREATE TABLE person (
            id             INTEGER  PRIMARY KEY,
            sei            TEXT     NOT NULL,
            mei            TEXT     NOT NULL,
            sei_yomi       TEXT     NOT NULL,
            mei_yomi       TEXT     NOT NULL,
            sei_sort_yomi  TEXT     NOT NULL,
            mei_sort_yomi  TEXT     NOT NULL,
            sei_romaji     TEXT     NOT NULL,
            mei_romaji     TEXT     NOT NULL,
            birthdate      TEXT     NOT NULL,
            deathdate      TEXT     NOT NULL
        )
    |);

    $dbi->execute(q|CREATE TABLE person_role (role TEXT PRIMARY KEY)|);

    for my $role (qw/著者 翻訳者 編者 校訂者 その他/)
    {
        $dbi->insert({ role => $role }, table => 'person_role');
    }

    $dbi->execute(q|
        CREATE TABLE role (
            work_id              INTEGER,
            person_id            INTEGER,
            role                 TEXT,
            is_out_of_copyright  INTEGER  NOT NULL  CHECK(is_out_of_copyright == 0 OR is_out_of_copyright == 1),
            PRIMARY KEY(work_id, person_id, role),
            FOREIGN KEY(work_id)    REFERENCES  work(id)           ON DELETE CASCADE,
            FOREIGN KEY(person_id)  REFERENCES  person(id)         ON DELETE CASCADE,
            FOREIGN KEY(role)       REFERENCES  person_role(role)  ON UPDATE CASCADE
        )
    |);

    $dbi->execute(q|
        CREATE TABLE book (
            id                      INTEGER  PRIMARY KEY AUTOINCREMENT,
            title                   TEXT     NOT NULL  CHECK(title != ''),
            publisher               TEXT     NOT NULL  DEFAULT '',
            first_publication_date  TEXT     NOT NULL  DEFAULT '',
            UNIQUE(title, publisher, first_publication_date)
        )
    |);

    $dbi->execute(q|
        CREATE TABLE source_book_of_work (
            work_id                   INTEGER,
            source_book_id            INTEGER,
            edition_for_input         TEXT     NOT NULL DEFAULT '',
            edition_for_proofreading  TEXT     NOT NULL DEFAULT '',
            PRIMARY KEY(work_id, source_book_id),
            FOREIGN KEY(work_id)         REFERENCES  work(id)  ON DELETE CASCADE,
            FOREIGN KEY(source_book_id)  REFERENCES  book(id)  ON DELETE CASCADE
        )
    |);

    $dbi->execute(q|
        CREATE TABLE parent_book_of_source_book (
            source_book_id  INTEGER  PRIMARY KEY,
            parent_book_id  INTEGER  NOT NULL,
            FOREIGN KEY(source_book_id)  REFERENCES  book(id)  ON DELETE CASCADE,
            FOREIGN KEY(parent_book_id)  REFERENCES  book(id)  ON DELETE CASCADE
        )
    |);
}
