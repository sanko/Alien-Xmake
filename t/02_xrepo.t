use v5.40;
use Test2::V0 '!subtest', -no_srand => 1;
use Test2::Util::Importer 'Test2::Tools::Subtest' => ( subtest_streamed => { -as => 'subtest' } );
use blib;
use Alien::Xmake;
use Alien::Xrepo;
#
ok $Alien::Xrepo::VERSION, 'Alien::Xrepo::VERSION';
#
my $repo  = Alien::Xrepo->new( verbose => $ENV{TEST_VERBOSE} // 0 );
my $xmake = Alien::Xmake->new;
my $exe   = $xmake->exe;
diag "Using Xmake at: $exe";

# Try to install libpng but skip if toolchain is missing on automated systems
my $pkg = eval { $repo->install('libpng') };
if ($@) {
    if ( $ENV{AUTOMATED_TESTING} || $ENV{PERL_CPAN_REPORTER_CONFIG} ) {
        skip_all "Skipping xrepo install test: toolchain might be missing or network issues: $@";
    }
    else {
        die $@;
    }
}

ok $pkg, 'install libpng';
skip_all 'Failed to install libpng', 3 unless $pkg;
diag 'Found library at: ' . $pkg->libpath;
diag 'Version: ' . $pkg->version;
diag 'License: ' . $pkg->license;
diag 'Header:  ' . $pkg->find_header('png.h');
diag 'Include dirs: ';
diag '     - ' . $_ for @{ $pkg->includedirs };
diag 'Lib:     ' . $pkg->libpath;
#
done_testing;
