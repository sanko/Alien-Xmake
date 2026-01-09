use v5.40;
use blib;
use Test2::V0 -no_srand => 1;
use File::Temp    qw[tempdir];
use Capture::Tiny qw[capture];
#
use Alien::Xmake;
#
my $xmake = Alien::Xmake->new;
my $exe   = $xmake->exe;
diag qx[$exe g --theme=plain] if $ENV{AUTOMATED_TESTING};
{
    my ( $stdout, $stderr, $exit ) = capture { system $exe, 'lua', 'private.xrepo', 'info', 'libpng' };
    diag $stdout;
    diag $stderr;

    #~ ok( ( -d 'test_cpp' ), 'project created' );
    ok !$exit, 'xmake --help';

    #~ diag $stdout if $exit && length $stdout;
    #~ diag $stderr if $exit && length $stderr;
    #~ chdir 'test_cpp';
    #~ subtest compile => sub {
    #~ my $todo = todo 'Require a working compiler';    # outside the scope of Alien::Xmake
    #~ diag 'Building project..';
    #~ ( $stdout, $stderr, $exit ) = capture { system $xmake->exe, '--quiet' };
    #~ ok !$exit, 'project built';
    #~ diag $stdout if $exit && length $stdout;
    #~ diag $stderr if $exit && length $stderr;
    #~ ( $stdout, $stderr, $exit ) = capture { system $xmake->exe, 'run' };
    #~ ok $stdout =~ /hello world!/, 'project says hello';
    #~ diag $stdout if $exit && length $stdout;
    #~ diag $stderr if $exit && length $stderr;
    #~ }
}
#
done_testing;
