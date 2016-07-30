#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use feature qw/say/;
use open qw/:encoding(utf-8) :std/;
use Try::Tiny;
use Text::CSV;
use DBIx::Custom;

my $csv_file = 'tools/list_person_all_extended_utf8.csv';
my $db_path  = 'bunko.sqlite3';

my $csv = Text::CSV->new({ binary => 1 });

my $dbi = DBIx::Custom->connect(
    dsn    => "dbi:SQLite:dbname=$db_path",
    option => { sqlite_unicode => 1, RaiseError => 1 },
);

$dbi->execute(q|PRAGMA foreign_keys = ON|);

open(my $fh, '<', $csv_file) or die $!;

while( my $column_list = $csv->getline($fh) )
{
    my $work_id               = $column_list->[0];
    my $work_title            = $column_list->[1];
    my $work_yomi             = $column_list->[2];
    my $work_sort_yomi        = $column_list->[3];
    my $subtitle              = $column_list->[4];
    my $subtitle_yomi         = $column_list->[5];
    my $original_title        = $column_list->[6];
    my $first_appearance      = $column_list->[7];
    my $ndc                   = $column_list->[8];
    my $moji_type             = $column_list->[9];
    my $is_out_of_copyright   = $column_list->[10];
    my $aozora_published_date = $column_list->[11];
    my $aozora_lastupdate     = $column_list->[12];
    my $card_url              = $column_list->[13];

    my $person_id                  = $column_list->[14];
    my $person_sei                 = $column_list->[15];
    my $person_mei                 = $column_list->[16];
    my $person_sei_yomi            = $column_list->[17];
    my $person_mei_yomi            = $column_list->[18];
    my $person_sei_sort_yomi       = $column_list->[19];
    my $person_mei_sort_yomi       = $column_list->[20];
    my $person_sei_romaji          = $column_list->[21];
    my $person_mei_romaji          = $column_list->[22];
    my $person_role                = $column_list->[23];
    my $person_birthdate           = $column_list->[24];
    my $person_deathdate           = $column_list->[25];
    my $is_person_out_of_copyright = $column_list->[26];

    my $source_book1_title                                 = $column_list->[27];
    my $source_book1_publisher                             = $column_list->[28];
    my $source_book1_first_publication_date                = $column_list->[29];
    my $source_book1_edition_for_input                     = $column_list->[30];
    my $source_book1_edition_for_proofreading              = $column_list->[31];
    my $parent_book_title_of_source_book1                  = $column_list->[32];
    my $parent_book_publisher_of_source_book1              = $column_list->[33];
    my $parent_book_first_publication_date_of_source_book1 = $column_list->[34];

    my $source_book2_title                                 = $column_list->[35];
    my $source_book2_publisher                             = $column_list->[36];
    my $source_book2_first_publication_date                = $column_list->[37];
    my $source_book2_edition_for_input                     = $column_list->[38];
    my $source_book2_edition_for_proofreading              = $column_list->[39];
    my $parent_book_title_of_source_book2                  = $column_list->[40];
    my $parent_book_publisher_of_source_book2              = $column_list->[41];
    my $parent_book_first_publication_date_of_source_book2 = $column_list->[42];

    my $data_entry_operator = $column_list->[43];
    my $proofreader         = $column_list->[44];

    my $text_url                  = $column_list->[45];
    my $text_lastupdate           = $column_list->[46];
    my $text_char_encoding_scheme = $column_list->[47];
    my $text_char_set             = $column_list->[48];
    my $text_revision_cnt         = $column_list->[49];

    my $html_url                  = $column_list->[50];
    my $html_lastupdate           = $column_list->[51];
    my $html_char_encofing_scheme = $column_list->[52];
    my $html_char_set             = $column_list->[53];
    my $html_revision_cnt         = $column_list->[54];

    next if $work_id =~ /作品ID/;

       if ($is_out_of_copyright eq 'あり') { $is_out_of_copyright = 0; }
    elsif ($is_out_of_copyright eq 'なし') { $is_out_of_copyright = 1; }
    else                                   { die '著作権フラグが不正'; }

       if ($is_person_out_of_copyright eq 'あり') { $is_person_out_of_copyright = 0; }
    elsif ($is_person_out_of_copyright eq 'なし') { $is_person_out_of_copyright = 1; }
    else                                          { die '人物著作権フラグが不正';    }

    try {
        $dbi->insert({
            id                        => $work_id,
            title                     => $work_title,
            title_yomi                => $work_yomi,
            title_sort_yomi           => $work_sort_yomi,
            subtitle                  => $subtitle,
            subtitle_yomi             => $subtitle_yomi,
            original_title            => $original_title,
            first_appearance          => $first_appearance,
            moji_type                 => $moji_type,
            is_out_of_copyright       => $is_out_of_copyright,
            aozora_published_date     => $aozora_published_date,
            aozora_lastupdate         => $aozora_lastupdate,
            card_url                  => $card_url,
            data_entry_operator       => $data_entry_operator,
            proofreader               => $proofreader,
            text_raw_utf8             => '',
            text_url                  => $text_url,
            text_lastupdate           => $text_lastupdate,
            text_char_set             => $text_char_set,
            text_char_encoding_scheme => $text_char_encoding_scheme,
            text_revision_cnt         => $text_revision_cnt,
            html_utf8                 => '',
            html_url                  => $html_url,
            html_lastupdate           => $html_lastupdate,
            html_char_set             => $html_char_set,
            html_char_encoding_scheme => $html_char_encofing_scheme,
            html_revision_cnt         => $html_revision_cnt,
        }, table => 'work');
    }
    catch { die $_ unless /unique constraint/i; }
    ;

    my @ndc_list = split(/\s/, $ndc);
    shift @ndc_list; # 「NDC」だけの要素を削る

    for my $ndc (@ndc_list)
    {
          try { $dbi->insert({ work_id => $work_id, ndc => $ndc }, table => 'NDC'); }
        catch { die $_ unless /unique constraint/i;                                 }
        ;
    }

    try {
        $dbi->insert({
            id            => $person_id,
            sei           => $person_sei,
            mei           => $person_mei,
            sei_yomi      => $person_sei_yomi,
            mei_yomi      => $person_mei_yomi,
            sei_sort_yomi => $person_sei_sort_yomi,
            mei_sort_yomi => $person_mei_sort_yomi,
            sei_romaji    => $person_sei_romaji,
            mei_romaji    => $person_mei_romaji,
            birthdate     => $person_birthdate,
            deathdate     => $person_deathdate,
        }, table => 'person');
    }
    catch { die $_ unless /unique constraint/i; }
    ;

    $dbi->insert({
        work_id             => $work_id,
        person_id           => $person_id,
        role                => $person_role,
        is_out_of_copyright => $is_person_out_of_copyright,
    }, table => 'role');

    if (length $source_book1_title)
    {
        try {
            $dbi->insert({
                title                  => $source_book1_title,
                publisher              => $source_book1_publisher,
                first_publication_date => $source_book1_first_publication_date,
            }, table => 'book');
        }
        catch { die $_ unless /unique constraint/i; }
        ;

        my $source_book1_id = $dbi->select(
            [qw/id/],
            table => 'book',
            where => {
                title                  => $source_book1_title,
                publisher              => $source_book1_publisher,
                first_publication_date => $source_book1_first_publication_date,
            }
        )->value;

        try {
            $dbi->insert({
                work_id                  => $work_id,
                source_book_id           => $source_book1_id,
                edition_for_input        => $source_book1_edition_for_input,
                edition_for_proofreading => $source_book1_edition_for_proofreading,
            }, table => 'source_book_of_work');
        }
        catch { die $_ unless /unique constraint/i; }
        ;

        if (length $parent_book_title_of_source_book1)
        {
            try {
                $dbi->insert({
                    title                  => $parent_book_title_of_source_book1,
                    publisher              => $parent_book_publisher_of_source_book1,
                    first_publication_date => $parent_book_first_publication_date_of_source_book1,
                }, table => 'book');
            }
            catch { die $_ unless /unique constraint/i; }
            ;

            my $parent_book1_id = $dbi->select(
                [qw/id/],
                table => 'book',
                where => {
                    title                  => $parent_book_title_of_source_book1,
                    publisher              => $parent_book_publisher_of_source_book1,
                    first_publication_date => $parent_book_first_publication_date_of_source_book1,
                }
            )->value;

            try {
                $dbi->insert({
                    source_book_id => $source_book1_id,
                    parent_book_id => $parent_book1_id,
                }, table => 'parent_book_of_source_book')
            }
            catch { die $_ unless /unique constraint/i; }
            ;
        }
    }

    if (length $source_book2_title)
    {
        try {
            $dbi->insert({
                title                  => $source_book2_title,
                publisher              => $source_book2_publisher,
                first_publication_date => $source_book2_first_publication_date,
            }, table => 'book');
        }
        catch { die $_ unless /unique constraint/i; };

        my $source_book2_id = $dbi->select(
            [qw/id/],
            table => 'book',
            where => {
                title                  => $source_book2_title,
                publisher              => $source_book2_publisher,
                first_publication_date => $source_book2_first_publication_date,
            }
        )->value;

        try {
            $dbi->insert({
                work_id                  => $work_id,
                source_book_id           => $source_book2_id,
                edition_for_input        => $source_book2_edition_for_input,
                edition_for_proofreading => $source_book2_edition_for_proofreading,
            }, table => 'source_book_of_work');
        }
        catch { die $_ unless/unique constraint/i }
        ;

        if (length $parent_book_title_of_source_book2)
        {
            try {
                $dbi->insert({
                    title                  => $parent_book_title_of_source_book2,
                    publisher              => $parent_book_publisher_of_source_book2,
                    first_publication_date => $parent_book_first_publication_date_of_source_book2,
                }, table => 'book');
            }
            catch { die $_ unless /unique constraint/i; }
            ;

            my $parent_book2_id = $dbi->select(
                [qw/id/],
                table => 'book',
                where => {
                    title                  => $parent_book_title_of_source_book2,
                    publisher              => $parent_book_publisher_of_source_book2,
                    first_publication_date => $parent_book_first_publication_date_of_source_book2,
                }
            )->value;

            try {
                $dbi->insert({
                    source_book_id => $source_book2_id,
                    parent_book_id => $parent_book2_id,
                }, table => 'parent_book_of_source_book')
            }
            catch { die $_ unless /unique constraint/i; }
            ;
        }
    }
}

close($fh);
