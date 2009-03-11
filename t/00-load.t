#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'CGI::Application::Plugin::GenVal' );
}

diag( "Testing CGI::Application::Plugin::GenVal $CGI::Application::Plugin::GenVal::VERSION, Perl $], $^X" );
