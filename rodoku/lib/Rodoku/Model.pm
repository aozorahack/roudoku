package Rodoku::Model;
use strict;
use warnings;
use utf8;

sub new
{
    my ($class, %arg) = @_;
    bless \%arg, $class;
}

sub fetch_work_list
{
    my ($self) = @_;

    my $work_list = $self->{dbi}->select(
        table  => 'work',
        column => [qw/id title subtitle/], # TODO: 著者名とかも欲しい
        append => 'ORDER BY id',
        where  => { moji_type => '新字新仮名' },
    )->fetch_hash_all // [];

    return $work_list;
}

sub fetch_work_text
{
    my ($self, $work_id) = @_;

    # TODO: いい具合にテキストを取得する
    my $work_text = $self->{dbi}->select(
        table    => 'work',
        column   => [qw/text_raw_utf8/],
        where    => { id => $work_id },
    )->value // '';

    return $work_text;
}

1;
