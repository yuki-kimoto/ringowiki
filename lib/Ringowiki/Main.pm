package Ringowiki::Main;
use Mojo::Base 'Mojolicious::Controller';
use Text::Markdown 'markdown';

sub admin {
  my $self = shift;
  
  my $wikies = $self->app->dbi->model('wiki')->select->all;
  
  return $self->render(wikies => $wikies);
}

sub index {
  my $self = shift;
  
  # Redirect to setup page
  return $self->redirect_to('/setup')
    unless $self->app->util->setup_completed;
  
  # Redirect to main wiki
  my $wiki = $self->app->dbi->model('wiki')
    ->select(append => 'order by main desc')->one;
  if ($wiki) {
    return $self->redirect_to(
      'page',
      wiki_id => $wiki->{id},
    );
  }
  
  $self->render;
}

sub page {
  my $self = shift;

  # Validation
  my $raw_params = {map { $_ => $self->param($_) } $self->param};
  my $rule = [
    wiki_id => ['word'],
    page_name => ['not_blank']
  ];
  my $vresult = $self->app->validator->validate($raw_params, $rule);
  my $params = $vresult->data;

  # DBI
  my $dbi = $self->app->dbi;
  
  # Wiki id
  my $wiki_id = $params->{wiki_id};
  unless (defined $wiki_id) {
    $wiki_id = $dbi->model('wiki')->select('id', append => 'order by main desc')->value;
  }
  
  # Page name
  my $page_name = $params->{page_name};
  unless (defined $page_name) {
    $page_name = $dbi->model('page')->select(
      'name',
      where => {wiki_id => $wiki_id},
      append => 'order by main desc'
    )->value;
  }
  
  # Page
  my $page = $dbi->model('page')->select(
    where => {wiki_id => $wiki_id, name => $page_name},
  )->one;

  return $self->render_not_found unless defined $page;
  
  # Content to html(Markdown)
  $page->{content} = markdown $self->_sanity($page->{content});
  
  $self->render(page => $page);
}

my $COMMENT_TAG_RE =
  qr/<!(?:--[^-]*-(?:[^-]+-)*?-(?:[^>-]*(?:-[^>-]+)*?)??)*(?:>|$(?!\n)|--.*$)/;

# Safety tags
my %SAFE_TAGS = map { $_ => 1 } qw/
  a
  abbr
  acronym
  address
  area
  b
  big
  blockquote
  br
  button
  caption
  center
  cite
  code
  col
  colgroup
  dd
  del
  dfn
  dir
  div
  dl
  dt
  em
  fieldset
  font
  form
  frameset
  h1
  h2
  h3
  h4
  h5
  h6
  hr
  i
  img
  input
  button
  ins
  kbd
  label
  legend
  li
  map
  menu
  ol
  optgroup
  option
  p
  q
  s
  samp
  select
  small
  span
  strike
  strong
  sub
  sup
  table
  tbody
  td
  textarea
  tfoot
  th
  thead
  tr
  tt
  u
  ul
  var
  pre
/;

my %SAFE_ATTRS = map { $_ => 1 } qw/
  abbr
  accept-charset
  accept
  accesskey
  action
  align
  alt
  axis
  border
  cellpadding
  cellspacing
  char
  charoff
  charset
  checked
  cite
  class
  clear
  color cols
  colspan
  compact
  coords
  datetime
  dir
  disabled
  enctype
  for
  frame
  headers
  height
  hreflang
  hspace
  ismap
  label
  lang
  longdesc
  maxlength
  media
  method
  multiple
  name
  nohref
  noshade
  nowrap
  prompt
  readonly
  rel
  rev
  rows
  rowspan
  rules
  scope
  selected
  shape
  size
  span
  start
  summary
  tabindex
  target
  title
  type
  usemap
  valign
  value
  vspace
  width
/;

my %SAFE_UNI_ATTRS = map { $_ => 1 } qw/
  checked
  compact
  multiple
  nohref
  noshade
  nowrap
  readonly
  selected
/;

my $TAG_RE = q/(<[^"'<>]*(?:"[^"]*"[^"'<>]*|'[^']*'[^"'<>]*)*(?:>|(?=<)|$(?!\n)))/;

sub _sanity {
  my ($self, $content) = @_;
  
  # Remove comment tags
  $content =~ s/$COMMENT_TAG_RE//go;
  
  # Remove unsafe tags
  my $content_new = '';
  my $open_tag_pos = CORE::index($content, '<');
  if ($open_tag_pos >= 0) {
    while (1) {
      $content_new .= substr($content, 0, $open_tag_pos, '');
      
      # Tag
      if ($content =~ s/$TAG_RE//) {
        my $whool = $1;
        
        # End slash
        my $end_slash;
        if ($whool =~ m#\s*/\s*>$#) {
          $end_slash = 1;
        }
        
        $whool =~ s/^<\s*//;
        
        # Close tag
        if ($whool =~ s#^\s*?/\s*?(.*?)(>|$)##) {
          my $tag = $1;
          if (defined $tag && $SAFE_TAGS{$tag}) {
            $content_new .= "</$tag>";
          }
        }
        # Open tag
        elsif ($whool =~ s#^\s*?(.*?)([\s>]|$)##) {
          my $tag = $1;
          if (defined $tag && $SAFE_TAGS{$tag}) {
            # Attributes
            my $attrs = {};
            while ($whool =~ /(([^=\s]+)\s*=\s*"([^"]+)("))/
              || $whool =~ /(([^=\s]+)\s*=\s*'([^']+)('))/
              || $whool =~ /(([^=\s]+)\s*=\s*([^<>'"\s]+))/)
            {
              my $part = $1;
              my $attr_name = $2;
              my $attr_value = $3;
              my $quote_type = $4 || '';
              $whool =~ s/\Q$part//;
              $attrs->{$attr_name}{value} = $attr_value;
              $attrs->{$attr_name}{quote_type} = $quote_type;
            }
            
            # Uni attributes
            while ($whool =~ /([^"'\/<>\s]+)/) {
              my $part = $1;
              $whool =~ s/\Q$part//;
              my $attr_name = $part;
              $attrs->{$attr_name}{value} = undef;
            }

            my $tag_new = "<$tag ";
            for my $attr_name (sort keys %$attrs) {
              if ($SAFE_UNI_ATTRS{$attr_name}) {
                $tag_new .= "$attr_name ";
              }
              elsif($SAFE_ATTRS{$attr_name}) {
                my $attr_value = $attrs->{$attr_name}{value};
                $attr_value = '' unless defined $attr_value;
                my $q = $attrs->{$attr_name}{quote_type} || '';
                $tag_new .= "$attr_name=$q$attr_value$q ";
              }
            }
            $tag_new .= '/' if $end_slash;
            $tag_new .= '>';
            
            $content_new .= $tag_new;
          }
        }
      }
      elsif ($content =~ /^</) { $content =~ s/^<\s*// }
      
      $open_tag_pos = CORE::index($content, '<');
      if ($open_tag_pos == -1) {
        $content_new .= $content;
        last;
      }
    }
  }
  else { $content_new .= $content }

  return $content_new;
}

1;
