package Ringowiki::Api::Admin::Wiki;
use Mojo::Base 'Mojolicious::Controller';

sub create {
  my $self = shift;
  
  my $raw_params = {map { $_ => $self->param($_) } $self->param};
  my $rule = [
    id => ['word']
  ];
  my $vresult = $self->app->validator->validate($raw_params, $rule);
  return $self->render(json => {success => 0, validation => $vresult->to_hash})
    unless $vresult->is_ok;
  my $params = $vresult->data;
  
  # DBI
  my $dbi = $self->app->dbi;
  
  # Create wiki
  my $model = $dbi->model('wiki');
  $dbi->connector->txn(sub {
    my $wiki = $model->select->one;
    $params->{main} = 1 unless $wiki;
    $model->insert($params);
  });
  
  $self->render(json => {success => 1});
}

1;
