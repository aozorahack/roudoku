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

    my $dbi = $self->{dbi};

    my $work_list = $dbi->select(
        table  => 'work',
        column => [qw/id title subtitle/], # TODO: 著者名とかも欲しい
        append => 'ORDER BY id',
        where  => { moji_type => '新字新仮名' }, # FIXME: ユーザが選択できるようにしたい
    )->fetch_hash_all // [];

    my $author_of_work_id = {};

    # FIXME: 大量のクエリが走るのでどうにかする
    for my $work (@{$work_list})
    {
       my $person_id = $dbi->select(
           table  => 'role',
           column => [qw/person_id/],
           where  => { work_id => $work->{id}, role => '著者' },
       )->value; # FIXME: 著者が複数名いても１名しか取っていない

       if ($person_id)
       {
            my $author_info = $dbi->select(
                table  => 'person',
                column => [qw/sei mei/],
                where  => { id => $person_id },
            )->fetch_hash_one;

            if ($author_info)
            {
                $work->{author} = $author_info->{sei} . $author_info->{mei};
            }
       }
    }

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
