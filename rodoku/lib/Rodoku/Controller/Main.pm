package Rodoku::Controller::Main;
use Mojo::Base 'Mojolicious::Controller';

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

        warn 'test';
    });

    $self->on(text => sub {
        my ($ws, $text) = @_;

        warn $text;
    });
}

1;
