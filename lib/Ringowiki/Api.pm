package Ringowiki::Api;
use Mojo::Base 'Mojolicious::Controller';

sub edit_wiki_page {
  my $self = shift;
  
  # Validation
  my $raw_params = {map { $_ => $self->param($_) } $self->param};
  my $rule = [
    wiki_id => ['not_blank'],
    page_name => ['not_blank'],
    content => ['any']
  ];
  my $vresult = $self->app->validator->validate($raw_params, $rule);
  return $self->render(json => {success => 0, validation => $vresult->to_hash})
    unless $vresult->is_ok;
  my $params = $vresult->data;
  my $wiki_id = $params->{wiki_id};
  my $page_name = $params->{page_name};
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

sub init_wiki {
  my $self = shift;
  
  my $dbi = $self->app->dbi;
  
  my $table_infos = $dbi->select(
    column => 'name',
    table => 'main.sqlite_master',
    where => "type = 'table' and name <> 'sqlite_sequence'"
  )->all;
  
  eval {
    $dbi->connector->txn(sub {
      for my $table_info (@$table_infos) {
        my $table = $table_info->{name};
        $self->app->dbi->execute("drop table $table");
      }
    });
  };
  
  my $success = !$@ ? 1 : 0;
  return $self->render_json({success => $success});
}

1;
