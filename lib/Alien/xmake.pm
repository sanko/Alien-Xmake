use v5.40;
use experimental 'class';
class Alien::Xmake 0.06 {
    use Path::Tiny qw[path];
    field $windows = $^O eq 'MSWin32';
    field $config : param //= sub {
        if ( eval 'require Alien::Xmake::ConfigData' ) {
            my $conf = { map { $_ => Alien::Xmake::ConfigData->config($_) } Alien::Xmake::ConfigData->config_names };

            # The raw 'bin' value in config is a relative path string.
            # We must call the generated helper method to get the absolute path.
            if ( Alien::Xmake::ConfigData->can('bin') ) {
                $conf->{bin} = Alien::Xmake::ConfigData->bin;
            }
            return $conf;
        }

        # Fallback / manual install detection
        return { install_type => 'system' };
        }
        ->();

    # We don't really need $dir detection if ConfigData is working,
    # but we keep it for fallback scenarios.
    field $dir;
    ADJUST {
        if ( !$config->{bin} || !-e $config->{bin} ) {
            ($dir) = grep { -d $_ } map { path($_)->child( qw[auto share dist Alien-Xmake], $windows ? () : 'bin' ) } @INC;
        }
    }

    # Pointless
    method cflags ()       {''}
    method libs ()         {''}
    method dynamic_libs () { }

    # Valuable
    method install_type () { $config->{install_type} }

    method bin_dir () {
        my $exe = $self->exe;
        return path($exe)->parent->stringify;
    }

    method exe () {
        my $bin = $config->{bin};

        # If ConfigData failed or we are in a fallback state:
        if ( !$bin && $dir ) {
            $bin = $dir->child( 'xmake' . ( $windows ? '.exe' : '' ) );
        }

        # Ensure we return a stringified absolute path safe for system()
        return path($bin)->absolute->stringify;
    }

    method xrepo () {

        # xrepo is usually in the same folder as Xmake
        my $exe        = path( $self->exe );
        my $xrepo_name = 'xrepo' . ( $windows ? '.bat' : '' );

        # Check sibling
        my $try = $exe->parent->child($xrepo_name);
        return $try->stringify if -e $try;

        # Fallback to config or raw lookup
        return $config->{bin} ? path( $config->{bin} )->parent->child($xrepo_name)->stringify : $xrepo_name;
    }
    method version ()             { $config->{version} }
    method config ( $key //= () ) { defined $key ? $config->{$key} : $config }

    sub alien_helper () {
        { xmake => sub { __PACKAGE__->new->exe }, xrepo => sub { __PACKAGE__->new->xrepo } }
    }
} 1;
__END__

=pod

=encoding utf-8

=head1 NAME

Alien::Xmake - Locate, Download, or Build and Install Xmake

=head1 SYNOPSIS

    use Alien::Xmake;

    system Alien::Xmake->exe, '--help';
    system Alien::Xmake->exe, qw[create -t qt.widgetapp test];

    system Alien::Xmake->xrepo, qw[info libpng];

=head1 DESCRIPTION

Xmake is a lightweight, cross-platform build utility based on Lua. It uses a Lua script to maintain project builds, but
is driven by a dependency-free core program written in C. Compared with Makefiles or CMake, the configuration syntax is
(in the opinion of the author) much more concise and intuitive. As such, it's friendly to novices while still
maintaining the flexibly required in a build system. With Xmake, you can focus on your project instead of the build.

Xmake can be used to directly build source code (like with Make or Ninja), or it can generate project source files like
CMake or Meson. It also has a built-in package management system to help users integrate C/C++ dependencies.

=head1 Methods

Not many are required or provided.

=head2 C<install_type()>

Returns 'system' or 'shared'.

=head2 C<exe()>

    system Alien::Xmake->exe;

Returns the full path to the Xmake executable.

=head2 C<xrepo()>

    system Alien::Xmake->xrepo;

Returns the full path to the L<xrepo|https://github.com/xmake-io/xmake-repo> executable.

=head2 C<bin_dir()>

    use Env qw[@PATH];
    unshift @PATH, Alien::Xmake->bin_dir;

Returns a list of directories you should push onto your PATH.

For a 'system' install this step will not be required.

=head2 C<version()>

    my $ver = Alien::Xmake->version;

Returns the version of Xmake installed.

Under a 'system' install, C<xmake --version> is run once and the version number is cached.

=head1 Alien::Base Helper

To use Xmake in your C<alienfile>s, require this module and use C<%{xmake}> and C<%{xrepo}>.

    use alienfile;
    # ...
        [ '%{xmake}', 'install' ],
        [ '%{xrepo}', 'install ...' ]
    # ...

=head1 Xmake Cookbook

xmake is severely underrated so I'll add more nifty things here but for now just a quick example.

You're free to create your own projects, of course, but Xmake comes with the ability to generate an entire project for
you:

    $ xmake create -P hi    # generates a basic console project in C++ and xmake.lua build script
    $ cd hi
    $ xmake -y              # builds the project if required, installing defined prerequisite libs, etc.
    $ xmake run             # runs the target binary which prints 'hello, world!'

C<xmake create> is a lot like C<minil new> in that it generates a new project for you that's ready to build even before
you change anything. It even tosses a C<.gitignore> file in. You can generate projects in C++, Go, Objective C, Rust,
Swift, D, Zig, Vale, Pascal, Nim, Fortran, and more. You can also generate boilerplate projects for simple console
apps, static and shared libraries, macOS bundles, GUI apps based on Qt or wxWidgets, IOS apps, and more.

See C<xmake create --help> for a full list.

=head1 Prerequisites

Windows simply downloads an installer but elsewhere, you gotta have git, make, and a C compiler installed to build and
install Xmake. If you'd like Alien::Xmake to use a pre-built or system install of Xmake, install it yourself first with
one of the following:

=over

=item Built from source

    $ curl -fsSL https://xmake.io/shget.text | bash

...or on Windows with Powershell...

    > Invoke-Expression (Invoke-Webrequest 'https://xmake.io/psget.text' -UseBasicParsing).Content

...or if you want to do it all by hand, try...

    $ git clone --recursive https://github.com/xmake-io/xmake.git
    # Xmake maintains dependencies via git submodule so --recursive is required
    $ cd ./xmake
    # On macOS, you may need to run: export SDKROOT=$(xcrun --sdk macosx --show-sdk-path)
    $ ./configure
    $ make
    $ ./scripts/get.sh __local__ __install_only__
    $ source ~/.xmake/profile

...or building from source on Windows...

    > git clone --recursive https://github.com/xmake-io/xmake.git
    > cd ./xmake/core
    > xmake

=item Windows

The easiest way might be to use the installer but you still have options.

=over

=item Installer

Download a 32- or 64-bit installer from https://github.com/xmake-io/xmake/releases and run it.

=item Via scoop

    $ scoop install xmake

See https://scoop.sh/

=item Via the Windows Package Manager

    $ winget install xmake

See https://learn.microsoft.com/en-us/windows/package-manager/

=item Msys/Mingw

    $ pacman -Sy mingw-w64-x86_64-xmake # 64-bit

    $ pacman -Sy mingw-w64-i686-xmake   # 32-bit

=back

=item MacOS with Homebrew

    $ brew install xmake

See https://brew.sh/

=item Arch

    # sudo pacman -Sy xmake

=item Debian

    # sudo add-apt-repository ppa:xmake-io/xmake
    # sudo apt update
    # sudo apt install xmake

=item Fedora/RHEL/OpenSUSE/CentOS

    # sudo dnf copr enable waruqi/xmake
    # sudo dnf install xmake

=item Gentoo

    # sudo emerge -a --autounmask dev-util/xmake

You'll need to add GURU to your system repository first.

=item FreeBSD

Build from source using gmake instead of make.

=item Android (Termux)

    $ pkg install xmake

=back

=head1 See Also

L<https://xmake.io/>

=head1 LICENSE

Copyright (C) Sanko Robinson.

This library is free software; you can redistribute it and/or modify it under the terms found in the Artistic License
2. Other copyrights, terms, and conditions may apply to data transmitted through this module.

=head1 AUTHOR

Sanko Robinson E<lt>sanko@cpan.orgE<gt>

=for stopwords xmake macOS wxWidgets CMake gotta FreeBSD MacOS

=cut
