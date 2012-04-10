package Ringowiki::Api;
use Mojo::Base 'Mojolicious::Controller';

sub edit_wiki_page {
  my $self = shift;
  
  # Validation
  my $raw_params = {map { $_ => $self->param($_) } $self->param};
  my $rule = [
    wiki_id => ['not_blank'],
    name => ['not_blank'],
    content => ['any']
  ];
  my $vresult = $self->app->validator->validate($raw_params, $rule);
  return $self->render(json => {success => 0, validation => $vresult->to_hash})
    unless $vresult->is_ok;
  my $params = $vresult->data;
  my $wiki_id = $params->{wiki_id};
  my $page_name = $params->{name};
  my $content = $params->{content};
  
  # DBI
  my $dbi = $self->app->dbi;
  
  # Update or insert
  my $model = $dbi->model('page');
  $dbi->connector->txn(sub {
    $model->update_or_insert({content => $content}, id => [$wiki_id, $page_name]);
  });
  
  # Render
  $self->render_json({success => 1});
}

