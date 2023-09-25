package Config::ROFL;

use strict;
use warnings;

use v5.10;

use Carp ();
use Config::ZOMG ();
use Data::Rmap ();
use File::Share ();
use Path::Tiny qw( cwd path );
use List::Util ();
use Scalar::Util qw( readonly );
use Types::Standard qw/Str HashRef/;

use Moo;
use namespace::clean;

my $orig_cwd;
BEGIN { $orig_cwd = Cwd::cwd; };

has 'global_path'  => is => 'lazy', isa => Str, default => '/etc/';
has 'config'       => is => 'rw',   lazy => 1,  builder => 1;
has 'config_path'  => is => 'lazy', isa => Str, builder => 1;
has 'default_dist' => is => 'lazy', default => '';
has 'dist'         => is => 'lazy', isa => Str, default => sub { shift->default_dist };
has 'dist_dir'     => is => 'lazy', coerce => sub { ref $_[0] eq 'Path::Tiny' ? $_[0] : path($_[0]); }, builder => 1;
has 'relative_dir' => is => 'lazy', coerce => sub { ref $_[0] eq 'Path::Tiny' ? $_[0] : path($_[0]); }, builder => 1;

sub _build_dist_dir {
  my $self = shift;

  my $path;
  # if testing, first relative path to ourselves
  if ($ENV{HARNESS_ACTIVE}) {
    $path = $self->_lookup_relative // $self->_lookup_by_dist;
  } else {
    $path = $self->_lookup_by_dist // $self->_lookup_relative;
  }

  die 'Could not find relative path (' . $self->relative_dir . ') , nor dist path (' . $self->dist . ')' unless $path;

  return path($path);
};

sub _build_relative_dir {
  my ($self) = @_;

  return $ENV{CONFIG_ROFL_RELATIVE_DIR} if $ENV{CONFIG_ROFL_RELATIVE_DIR};

  my $pm = _class_to_pm(ref $self);
  if ($INC{$pm}) {
    my $path = $INC{$pm};
    $path =~ s{$pm}{};
    $path = path($path)->parent->child('share');
    return $path;
  }
}

has 'mode' => (
  is      => 'lazy',
  isa     => Str,
  default => sub { $ENV{CONFIG_ROFL_MODE} // ($ENV{HARNESS_ACTIVE} && 'test' || 'dev') },
);
has 'name' => (is => 'lazy', isa => Str, default => sub { $ENV{CONFIG_ROFL_NAME} || 'config' });
has 'max_age' => (is => 'lazy', isa => Str, default => sub {0});

with 'MooX::Singleton';

sub BUILD {
   my ($self, $args) = @_;

   die "You need to either subclass " . __PACKAGE__ . " or pass in dist_dir, to use a custom dist"
     if $args->{dist} && ref $self eq __PACKAGE__ && !$args->{dist_dir};
}

sub _build_config {    ## no critic(Subroutines::ProhibitUnusedPrivateSubroutines)
  my ($self) = @_;

  my $config = Config::ZOMG->new(
    name         => $self->name,
    path         => $self->config_path,
    local_suffix => $self->mode,
    driver =>
      # These options are only applicable when config ends up loaded by Config::General
      { General => {'-LowerCaseNames' => 1, '-InterPolateEnv' => 1, '-InterPolateVars' => 1,}, }
  );

  $config->load;

  if ($config->found) {
    _post_process_config($config->load);
    say {*STDERR} "Loaded configs: " . (
        join ', ',
        map {
          my $realpath = path($_)->realpath;
          my $rel_path = cwd->relative($realpath);
          $rel_path =~ /^\.\./ ? $realpath : $rel_path
        } $config->found
      ) if $ENV{CONFIG_ROFL_DEBUG};
  }
  else {
    Carp::croak 'Could not find config file: ' . $self->config_path . '/' . $self->name . '.(conf|yml|json)';
  }

  return $config;
}

around 'config' => sub {
  my $orig = shift;
  my $self = shift;

  return $orig->($self, @_)->load;
};

sub _build_config_path {
  my $self = shift;
  return $ENV{CONFIG_ROFL_CONFIG_PATH} // (
    (
      List::Util::first {-e}
      glob path($self->global_path, $self->name) . '.{conf,yml,yaml,json,ini}'
    ) ? $self->global_path : $self->dist_dir . '/etc'
  );
}


sub _post_process_config {
  my ($hash) = @_;

  Data::Rmap::rmap_scalar {
    defined $_ && (!readonly $_) && ($_ =~ s/__ENV\((\w+)\)__/env_substitute($1)/eg);
  }
  $hash;

  return;
}

sub env_substitute {
  my ($prefix) = @_;
  return $ENV{$prefix} || '';
}

sub get {
  my ($self, @keys) = @_;

  return List::Util::reduce { $a->{$b} || $a->{lc $b} } $self->config, @keys;
}

sub share_dir  { shift->dist_dir->child(@_) }
sub share_file { shift->dist_dir->child(@_) }

sub _class_to_pm {
  my ($module) = @_;
  $module =~ s{(-|::)}{/}g;
  return "$module.pm";
}

sub _lookup_relative {
  my ($self) = @_;

  my $path = $self->relative_dir;
  return $path if $path->exists;
}

sub _lookup_by_dist {
  my ($self) = @_;

  return eval { File::Share::dist_dir($self->dist) } || eval { File::Share::dist_dir(ref $self) } || undef;
}



1;

=encoding utf8

=head1 NAME

Config::ROFL - Yet another Yet Another Config Module

=head1 SYNOPSIS

    use Config::ROFL;
    my $config = Config::ROFL->new()
    $config->get("frobs");

    $config->share_file("system.yml");
    $config->share_dir("assets");

=head1 DESCRIPTION

=head1 ATTRIBUTES

=head2 config

=head2 dist

=head2 dist_dir

=head2 global_path

=head2 mode

=head2 name

=head2 config_path

=head1 METHODS

=head2 env_substitute

=head2 get

=head2 new

=head2 share_file

=head2 share_dir

=head1 COPYRIGHT

Nicolas Mendoza 2023 - All rights reserved

=cut
