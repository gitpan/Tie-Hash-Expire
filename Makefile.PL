use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Tie::Hash::Expire',
    AUTHOR              => 'Colin Wetherbee <cww@cpan.org>',
    VERSION_FROM        => 'lib/Tie/Hash/Expire.pm',
    ABSTRACT_FROM       => 'lib/Tie/Hash/Expire.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'Tie::Hash'  => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Tie-Hash-Expire-*' },
);
