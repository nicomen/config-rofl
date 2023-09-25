use inc::Module::Install;
use strict;
use warnings;

name 'Config-ROFL';
author q{Nicolas Mendoza <mendoza@pvv.ntnu.no>};
license 'perl';
version '1.0';

configure_requires 'Module::Install';

build_requires 'Test::More';

requires 'Cwd';
requires 'Carp';
requires 'Config::General';
requires 'Cpanel::JSON::XS' => '4.04';
requires 'Config::ZOMG';
requires 'Data::Rmap';
requires 'File::Share';
requires 'File::Spec';
requires 'List::Util' => '1.33';    # 1.33 needed for 'any'
requires 'Moo';

test_requires 'Test::Output';

install_script glob('script/*');
install_share 'share';

auto_install;

WriteAll;
