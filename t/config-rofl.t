#!/usr/bin/perl

use strict;
use warnings;

use Cwd qw( getcwd );
use FindBin qw( $Bin );
use Test::Exception;
use Test::More;
use Test::Output qw( stderr_like stderr_unlike );
use Path::Tiny ();

use Config::ROFL ();

$ENV{CONFIG_ROFL_DEBUG} = 1;
$ENV{CONFIG_ROFL_RELATIVE_DIR} = "$Bin/data/config/share";

subtest 'Object interface' => sub {
  my $c = Config::ROFL->new;

  my ($c1, $c2, $c3);

  {
    no warnings 'redefine';
    local *Test::More::note = sub { warn @_; }; ## no critic (Policy::Variables::ProtectPrivateVars)
    stderr_like { $c1 = $c->get('App::DBI') } qr/Loaded config/, 'Loaded config first time';
    stderr_unlike { $c2 = $c->get('App::DBI', 'serVER') } qr/Loaded config/,
      'Did not load config again';
    stderr_unlike { $c3 = $c->get('App::DBI', 'SERVER') } qr/Loaded config/,
      'Did not load config again';
  };

  {
    no warnings 'redefine';
    local *Test::More::note = sub { warn @_; }; ## no critic (Policy::Variables::ProtectPrivateVars)
    stderr_like { Config::ROFL->instance->get('App::dbi', 'serVER') }
      qr/Loaded config/, 'Did not load config again (default singleton) (instance method)';
    stderr_unlike { Config::ROFL->instance->get('App::dbi', 'serVER') }
      qr/Loaded config/, 'Did not load config again (default singleton) (instance method)';
  };

  is_deeply($c1->{server}, $c2, 'Case-insensitive lookup works');
  is_deeply($c2,           $c3, 'Case-insensitive lookup works');


  my $main_path = Path::Tiny->new('/tmp/config.conf');
  my $prod_path = Path::Tiny->new('/tmp/config_production.conf');
  my $test_path = Path::Tiny->new('/tmp/config_test.conf');

  $main_path->spew(<<'__CONFIG_END__')
<App::DBI>
   <Database>
       mode = default
       default_value = default
   </Database>
</App::DBI>
__CONFIG_END__
    ;

  $test_path->spew(<<'__CONFIG_END__')
<App::DBI>
   <Database>
       mode = test
   </Database>
</App::DBI>
__CONFIG_END__
    ;

  $prod_path->spew(<<'__CONFIG_END__')
<App::DBI>
   <Database>
       mode = production
   </Database>
</App::DBI>
__CONFIG_END__
    ;

  {
    my $c = Config::ROFL->new( config_path => '/tmp');
    is($c->get('App::DBI', 'database')->{mode}, 'test', 'Default loads test (when run with prove)');
    is($c->get('App::DBI', 'database')->{default_value},
      'default', 'Default loads test (when run with prove)');
  };

};

subtest 'Test ENV replacement for Config::General' => sub {
  local $ENV{CONFIG_ROFL_CONFIG_PATH} = "$Bin/data/config";
  local $ENV{LOL}            = 'LOL Was replaced';

  my $c = Config::ROFL->new(unique => 1);

  is $c->get('App::DBI', 'database')->{value}, 'LOL Was replaced',
    'Correct __ENV(...)__ env-var replacement';
};

subtest 'Test ENV replacement for JSON' => sub {
  local $ENV{CONFIG_ROFL_CONFIG_PATH}      = "$Bin/data/config/json";
  local $ENV{LOL}                 = 'LOL Was replaced';
  local $ENV{LOL_WITH_UNDERSCORE} = 'LOL_WITH_UNDERSCORE Was replaced';

  my $c = Config::ROFL->new(unique => 1);

  is $c->get('App::DBI', 'Database')->{value1}, 'LOL Was replaced',
    'Correct __ENV(...)__ env-var replacement';
  is $c->get('App::DBI', 'Database')->{value2}, 'LOL_WITH_UNDERSCORE Was replaced',
    'Correct __ENV(...)__ env-var replacement with underscore in var-name';
};

subtest 'Check that global_path override works' => sub {
  my $c = Config::ROFL->new(unique => 1, dist_dir => "$Bin/data/config");
  is $c->get("foo"), 'original', 'Got original config';

  my $c2 = Config::ROFL->new(
    unique      => 1,
    dist_dir    => "$Bin/data/config",
    global_path => "$Bin/data/config/overriden_config_path"
  );
  is $c2->get("foo"), 'overriden', 'Got overriden config';
};

subtest 'Check that YAML true values work' => sub {
  my $c = Config::ROFL->new(unique => 1, config_path => "$Bin/data/config/yaml_true_value");
  lives_ok { $c->get('foo', 'bar'); } 'True value should not die';
};

subtest 'Shared directories' => sub {
  my $c = Config::ROFL->new;
  ok -d $c->share_dir, 'share_dir';
  ok -d $c->share_dir('etc'), 'share_dir etc';
  ok -f $c->share_file(qw(etc config.yaml)), 'share_file etc/config.yaml';
};

subtest 'Shared directories' => sub {
  my $old_dir = getcwd;
  chdir "/tmp";
  my $c = Config::ROFL->new( unique => 1 );
  ok -d $c->share_dir, 'share_dir';
  ok -d $c->share_dir('etc'), 'share_dir etc';
  ok -f $c->share_file(qw(etc config.yaml)), 'share_file etc/config.yaml';
  chdir $old_dir;
};

done_testing;
