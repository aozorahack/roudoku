package Rodoku::Controller::Main;
use Mojo::Base 'Mojolicious::Controller';
use Encode ();

sub top
{
    my $self  = shift;
    my $model = $self->model;
    return $self->render(work_list => $model->fetch_work_list);
}

# 声をWAV形式に変換
sub voice2wav
{
    my $self   = shift;
    my $model  = $self->model;
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

    my $voice_work_dir = 'test'; # 朗読対象のテキストの名前（保存パスに利用）

    $self->on(binary => sub {
        my ($self, $bytes) = @_;

        my $file_path = $config->{rodoku_voice_dir} . $voice_work_dir . '/' . $username . '_' . $self->timestampf . '_'  . $self->uniqkey . '.wav';

        # 音声をファイルに保存
        open(my $fh, '>', $file_path) or die $!;
        binmode($fh);
        print {$fh} $bytes;
        close($fh);

        # 朗読リストを更新
        my $dir_path = $config->{rodoku_voice_dir} . $voice_work_dir;

        opendir(my $dh, $dir_path);
        my @rodoku_wav_list = grep { ! /^\..*$/ } readdir $dh;
        closedir($dh);

        $tx->send( { json => { type => 'rodoku_list_update', rodoku_list => \@rodoku_wav_list } } );
    });

    $self->on(json => sub {
        my ($ws, $json) = @_;

        my $type = $json->{type};

        return unless defined $type;

        if ($type eq 'work-select')
        {
            my $work_id = $json->{'work_id'} // 'test';


            my $dir_path = $config->{rodoku_voice_dir} . $work_id;

            opendir(my $dh, $dir_path);
            my @rodoku_wav_list = grep { ! /^\..*$/ } readdir $dh;
            closedir($dh);

            $tx->send( { json => { type => $type, text => $text, rodoku_list => \@rodoku_wav_list } } );

            $voice_work_dir = $work_id;
        }
        elsif ($type eq 'rodoku-reproduction')
        {
            my $file_path = $config->{rodoku_voice_dir} . $voice_work_dir . '/' . $json->{filename};

            open(my $fh, '<', $file_path) or die $!;
            binmode($fh);
            my $size = -s $file_path;
            read($fh, my $buffer, $size, 0);
            close($fh);

            $tx->send({ binary => $buffer });
        }
        elsif ($type eq 'username-change')
        {
            if ($json->{username} =~ /^[a-zA-Z0-9-]+$/)
            {
                $username = $json->{username};
            }
            else
            {
                $tx->send( { json => { type => $type, error => '名前は英語のアルファベットで入力してください' } } );
            }
        }
    });

    $self->on(text => sub {
        my ($ws, $msg) = @_;

        # keep alive
    });
}

1;
