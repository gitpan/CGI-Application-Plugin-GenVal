use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'CGI::Application::Plugin::GenVal',
    AUTHOR              => 'Lyle Hopkins <webmaster@cosmicperl.com>',
    VERSION_FROM        => 'lib/CGI/Application/Plugin/GenVal.pm',
    ABSTRACT_FROM       => 'lib/CGI/Application/Plugin/GenVal.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More'      => 0,
        'YAML'            => 0.67,
        'Perl6::Junction' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'CGI-Application-Plugin-GenVal-*' },
);
