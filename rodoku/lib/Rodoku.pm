package Rodoku;
use Mojo::Base 'Mojolicious';
use Data::Lock    ();
use Data::Printer ();

# This method will run once at server start
sub startup
{
    my $self   = shift;
    my $app    = $self->app;
    my $config = $self->plugin('Config'); # rodoku.conf を読み込む

    $self->plugin('xslate_renderer');

    # 例外時のメールの設定（UTF-8で送るので文字コード変更の必要なし）
    $self->plugin(MailException => {
        from    => "$config->{site_title} <$config->{admin_mail}>",
        to      => $config->{admin_mail},
        subject => "Site Crashed! - $config->{site_title}",
    });

    Data::Lock::dlock   $config;              # 設定をリードオンリーにする
    Data::Lock::dunlock $config->{hypnotoad}; # hypnotoad はサーバ起動時に一部書き換えが発生するので例外

    # ルーティング
    my $r = $self->routes;
    $r->get('/')->to('main#top');
    $r->websocket('/voice2wav')->to('main#voice2wav');
}

1;
