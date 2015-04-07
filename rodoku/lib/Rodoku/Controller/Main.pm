package Rodoku::Controller::Main;
use Mojo::Base 'Mojolicious::Controller';
use Encode ();

sub top { shift->render; }

# 声をWAV形式に変換
sub voice2wav
{
    my $self   = shift;
    my $config = $self->config;
    my $tx     = $self->tx;

    # オリジンのチェック
    my $origin = $self->req->headers->header('origin') // '';
    return $self->render(text => 'Invalid Origin', status => '403') if $origin ne $config->{origin};

    # クライアントの接続のタイムアウト時間の変更
    $self->inactivity_timeout($config->{inactivity_timeout});

    $self->on(binary => sub {
        my ($self, $bytes) = @_;

        my $file_path = $config->{rodoku_voice_dir} . $self->uniqkey . '_'  . $self->timestampf . '.wav';

        # 音声をファイルに保存
        open(my $fh, '>', $file_path) or die $!;
        binmode($fh);
        print {$fh} $bytes;
        close($fh);
    });

    $self->on(json => sub {
        my ($ws, $json) = @_;

        my $type = $json->{type};

        return unless defined $type;

        if ($type eq 'text-select')
        {
            my $text_name = $json->{'text-name'};
            my $file_path = $config->{rodoku_text_dir} . $text_name . '.txt';

            if ( $text_name =~ /^[a-zA-Z0-9]+$/ && -e $file_path )
            {

                open(my $fh, '<', $file_path) or $tx->send( { json => { type => $type, error => 'ファイルの読み込みに失敗しました。' } } );
                my $text = Encode::decode_utf8( do { local $/; <$fh> } );
                close($fh);

                $tx->send( { json => { type => $type, text => $text } } );
            }
            else
            {
                $tx->send( { json => { type => $type, error => '朗読するテキストの選択が不正です。' } } );
            }
        }
    });

    $self->on(text => sub {
        my ($ws, $msg) = @_;

        # keep alive
    });
}

1;
