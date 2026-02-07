use v5.40;
use feature qw[class try];
no warnings 'experimental::class', 'experimental::try';

class Alien::Xmake 0.08 {
    use File::Spec;
    use File::Basename qw[dirname];

    #
    field $windows = $^O eq 'MSWin32';
    field $config : param //= undef;
    field $dir;

    ADJUST {
        if ( !defined $config ) {
            try {
                require Alien::Xmake::ConfigData;
                $config = { map { $_ => Alien::Xmake::ConfigData->config($_) } Alien::Xmake::ConfigData->config_names };
                if ( Alien::Xmake::ConfigData->can('bin') ) {
                    $config->{bin} = Alien::Xmake::ConfigData->bin;
                }
            }
            catch ($e) {
                $config = { install_type => 'system' };
            }
        }

        if ( !$config->{bin} || !-e $config->{bin} ) {
            my @parts = qw[auto share dist Alien-Xmake];
            push @parts, 'bin' unless $windows;
            foreach my $inc (@INC) {
                my $d = File::Spec->catdir( $inc, @parts );
                if ( -d $d ) {
                    $dir = $d;
                    last;
                }
            }
        }
    }

    # Pointless stubs required by some Alien::Base consumers
    method cflags ()       { '' }
    method libs ()         { '' }
    method dynamic_libs () { }

    # Valuable
    method install_type () { $config->{install_type} }

    method bin_dir () {
        my $exe = $self->_resolve_path;
        return dirname($exe);
    }

    method exe () {
        my $path = $self->_resolve_path;
        return $self->_quote_path($path);
    }

    method xrepo () {
        my $exe_path   = $self->_resolve_path;
        my $parent     = dirname($exe_path);
        my $xrepo_name = 'xrepo' . ( $windows ? '.bat' : '' );

        my $try = File::Spec->catfile( $parent, $xrepo_name );
        return $self->_quote_path($try) if -e $try;

        if ( $config->{bin} ) {
            my $conf_parent = dirname( $config->{bin} );
            my $target      = File::Spec->catfile( $conf_parent, $xrepo_name );
            return $self->_quote_path($target) if -e $target;
        }

        return $xrepo_name;
    }

    method pkg_config ($package) {
        my $xrepo = $self->xrepo;
        system( $xrepo, 'install', '-y', $package ) == 0 || die "Alien::Xmake: Could not install package '$package'\n";
        my $cflags = qx|$xrepo fetch --cflags "$package"|;
        chomp $cflags;
        my $libs = qx|$xrepo fetch --ldflags "$package"|;
        chomp $libs;
        return { cflags => $cflags, libs => $libs };
    }

    method version ()             { $self->install_type eq 'system' ? $self->_getver : $config->{version} }
    method build ()               { $self->_getbuild }
    method config ( $key //= () ) { defined $key ? $config->{$key} : $config }

    sub alien_helper () {
        { xmake => sub { __PACKAGE__->new->exe }, xrepo => sub { __PACKAGE__->new->xrepo } }
    }

    method _getver () {
        my ( $ver, undef ) = $self->_getver_build;
        "v$ver";
    }

    method _getbuild () {
        my ( undef, $build ) = $self->_getver_build;
        $build;
    }

    method _getver_build () {
        my $cmd = $self->exe;
        state $out //= qx[$cmd --version];
        return ( $1, $2 ) if $out =~ /xmake\s+v?(\d+\.\d+\.\d+)(?:\+(.+),)?/i;
        ( '0.0.0', () );
    }

    method _resolve_path () {
        my $bin = $config->{bin};
        $bin = File::Spec->catfile( $dir, 'xmake' . ( $windows ? '.exe' : '' ) ) if !$bin && $dir;
        $bin //= 'xmake';
        File::Spec->rel2abs($bin);
    }

    method _quote_path ($path) {
        return qq{"$path"} if $windows && $path =~ /\s/;
        $path;
    }
}
1;
__END__

=head1 NAME

Alien::Xmake - Locate, Download, or Build and Install Xmake

=head1 SYNOPSIS

    use Alien::Xmake;
    my $xmake = Alien::Xmake->new;
    system $xmake->exe, '--help';

=head1 DESCRIPTION

Alien::Xmake provides Xmake, a lightweight, cross-platform build utility based on Lua.

=head1 LICENSE

Copyright (C) Sanko Robinson.

This library is free software; you can redistribute it and/or modify it under the terms found in the Artistic License 2.