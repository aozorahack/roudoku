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

    # WebSocketのメッセージサイズの最大値を変更
    $tx->max_websocket_size($config->{max_websocket_size});

    my $username = $config->{default_username};

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
        elsif ($type eq 'username-change')
        {
            if ($json->{username} =~ /^\p{InUserName}+$/)
            {
                $username = $json->{username};
            }
            else
            {
                $tx->send( { json => { type => $type, error => 'ひらがな・カタカナ・アルファベット・漢字で入力してください' } } );
            }
        }
    });

    $self->on(text => sub {
        my ($ws, $msg) = @_;

        # keep alive
    });
}

sub InUserName
{
    # 0021-007E 英語のアルファベットや半角の記号など
    # 3005      々
    # 3041-3096 ひらがな
    # 309D      ゝ
    # 309E      ゞ
    # 30A1-30FE カタカナ

    return <<"END";
0021\t007E
3005
3041\t3096
309D
309E
30A1\t30FE
+utf8::Han
END
}

1;
