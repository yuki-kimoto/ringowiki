package Ringowiki::HTMLFilter;
use Object::Simple -base;

my $COMMENT_TAG_RE =
  qr/<!(?:--[^-]*-(?:[^-]+-)*?-(?:[^>-]*(?:-[^>-]+)*?)??)*(?:>|$(?!\n)|--.*$)/;

my $TAG_RE = q/(<[^"'<>]*(?:"[^"]*"[^"'<>]*|'[^']*'[^"'<>]*)*(?:>|(?=<)|$(?!\n)))/;

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
  href
  lang
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

sub sanitize_tag {
  my ($self, $content) = @_;
  
  # Remove comment tags
  $content =~ s/$COMMENT_TAG_RE//go;
  
  # Remove unsafe tags
  my $content_new = '';
  my $open_tag_pos = index($content, '<');
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
      
      $open_tag_pos = index($content, '<');
      if ($open_tag_pos == -1) {
        $content_new .= $content;
        last;
      }
    }
  }
  else { $content_new .= $content }

  return $content_new;
}

sub parse_wiki_link {
  my ($self, $c, $content, $wiki_id) = @_;
  
  my $to_a = sub {
    my ($page_name, $text) = @_;
    
    # DBI
    my $page = $c->app->dbi->model('page')->select(
      where => {wiki_id => $wiki_id, name => $page_name}
    )->one;
    
    my $link;
    if ($page) {
      $link = '<a href="'
        . $c->url_for('page', wiki_id => $wiki_id, page_name => $page_name)
        . '" class=' . ($page ? '"page_link"' : '"page_link_not_found"') . '>' . "$text</a>";
    }
    else {
      $link = '<a href="'
        . $c->url_for('edit-page', wiki_id => $wiki_id, page_name => $page_name)
        . '" class=' . ($page ? '"page_link"' : '"page_link_not_found"') . '>' . "$text</a>";
    }
    
    return $link;
  };
  
  $content =~ s/\[\[\s*(.*?)\s*?\|\s*(.*?)\s*\]\]/$to_a->($1, $2)/ge;
  $content =~ s/\[\[\s*(.*?)\s*\]\]/$to_a->($1, $1)/ge;
  
  return $content;
}

