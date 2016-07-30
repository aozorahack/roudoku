#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use feature qw/say/;
use open qw/:encoding(utf-8) :std/;
use Encode qw/decode/;
use DBIx::Custom;
use LWP::UserAgent;
use IO::Uncompress::Unzip;
use IO::String;
use File::Spec;

my $blocksize = 1024 * 50; # ZIPファイル読み込み時のバッファ・サイズ

my $db_path = 'bunko.sqlite3';

my $dbi = DBIx::Custom->connect(
    dsn    => "dbi:SQLite:dbname=$db_path",
    option => { sqlite_unicode => 1, RaiseError => 1 },
);

my $ua = LWP::UserAgent->new;

$dbi->execute(q|PRAGMA foreign_keys = ON|);

my $result = $dbi->select(
    [qw/id is_out_of_copyright text_url text_char_encoding_scheme html_url html_char_encoding_scheme/],
    table  => 'work',
    append => 'ORDER BY id ASC',
);

while (my $row = $result->fetch_hash)
{
    say $row->{id};
    say $row->{text_url}                  // 'undef';
    say $row->{text_char_encoding_scheme} // 'undef';
    say $row->{html_url}                  // 'undef';
    say $row->{html_char_encoding_scheme} // 'undef';

    # フォーマット統一のため、青空文庫の外のリソース場合はスキップする
    next if $row->{text_url} !~ m|^http://www\.aozora\.gr\.jp/|;
    next if $row->{html_url} !~ m|^http://www\.aozora\.gr\.jp/|;

    # 著作権があればスキップする
    next if $row->{is_out_of_copyright} == 0;

    if (length $row->{text_url})
    {
        my $response = $ua->get($row->{text_url});

        if ($response->is_success)
        {
            say 'テキストの取得：成功';

            my $text;

            if ($row->{text_url} =~ /\.zip$/i)
            {
                my $unzip = IO::Uncompress::Unzip->new(IO::String->new($response->decoded_content));

                for (my $unzip_state = 1; $unzip_state > 0; $unzip_state = $unzip->nextStream())
                {
                    my $header = $unzip->getHeaderInfo();

                    my (undef, undef, $file_name) = File::Spec->splitpath($header->{Name});

                    if ($file_name =~ /\.txt$/i)
                    {
                        my $buff;

                        my $out = IO::String->new;

                        while (1)
                        {
                            my $status = $unzip->read($buff, $blocksize);
                            last if $status <= 0;
                            $out->print($buff);
                        }

                        $text = decode($row->{text_char_encoding_scheme}, ${$out->string_ref});

                        last;
                    }
                }
            }
            else
            {
                $text = $response->decoded_content(charset => $row->{text_char_encoding_scheme});
            }

            $dbi->update({ text_raw_utf8 => $text }, table => 'work', where => { id => $row->{id} });
        }
        else
        {
            say 'テキストの取得：失敗';
        }
    }

    if (length $row->{html_url})
    {
        my $response = $ua->get($row->{html_url});

        if ($response->is_success)
        {
            say 'HTMLの取得：成功';

            my $text;

            if ($row->{html_url} =~ /\.zip$/i)
            {
                my $unzip = IO::Uncompress::Unzip->new(IO::String->new($response->decoded_content));

                while ( $unzip->nextStream() )
                {
                    my $header = $unzip->getHeaderInfo();
                    my (undef, undef, $file_name) = File::Spec->splitpath($header->{Name});

                    if ($file_name =~ /\.txt$/i)
                    {
                        my $buff;

                        my $out = IO::String->new;

                        while (1)
                        {
                            my $status = $unzip->read($buff, $blocksize);
                            last if $status <= 0;
                            $out->print($buff);
                        }

                        $text = decode($row->{html_char_encoding_scheme}, ${$out->string_ref});

                        last;
                    }
                }
            }
            else
            {
                $text = $response->decoded_content(charset => $row->{html_char_encoding_scheme});
            }

            $dbi->update({ html_utf8 => $text }, table => 'work', where => { id => $row->{id} });
        }
        else
        {
            say 'HTMLの取得：失敗';
        }
    }

    sleep(1);
}
