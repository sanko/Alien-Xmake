use v5.40;
use feature 'class';
no warnings 'experimental::class';

class Alien::Xrepo 0.08 {
    use Carp qw(croak);
    use JSON::PP qw(decode_json);
    use Alien::Xmake;
    use Capture::Tiny qw(capture);
    use Path::Tiny;
    #
    field $verbose : param //= 0;
    field $xmake = Alien::Xmake->new;
    field $xrepo : param //= $xmake->xrepo;

    # ============================================================================
    # METHODS
    # ============================================================================

    method install ($package_name, $version_constraint = undef, %options) {
        my $pkg_spec = $package_name;
        $pkg_spec .= " $version_constraint" if defined $version_constraint && length $version_constraint;

        # 1. Install phase
        my @args = $self->_build_cli_options(\%options);
        my @install_cmd = ($xrepo, 'install', '-y', @args, $pkg_spec);
        $self->_run_command(@install_cmd);

        # 2. Introspection phase (fetch)
        my @fetch_cmd = ($xrepo, 'fetch', '--json', @args, $pkg_spec);
        my $json_output = $self->_run_command(@fetch_cmd);

        # Sanitize Output (deal with loading animations or warnings)
        $json_output = $self->_apply_backspace_characters($json_output);
        if ($json_output =~ /(\[.*\])/s) {
            $json_output = $1;
        }

        my $meta_list = eval { decode_json($json_output) };
        if ($@) {
            croak "Failed to parse xrepo JSON output: $@\nRaw output:\n$json_output";
        }
        if (!$meta_list || ref $meta_list ne 'ARRAY' || !@$meta_list) {
            croak "Failed to fetch metadata for package '$package_name'";
        }

        return $self->_process_info($meta_list->[0]);
    }

    method uninstall ($package_name, %options) {
        my @cmd = ($xrepo, 'remove', '-y');
        push @cmd, $self->_build_cli_options(\%options);
        push @cmd, $package_name;
        $self->_run_command(@cmd);
        return 1;
    }

    method search ($query) {
        system($xrepo, 'search', $query);
    }

    method clean () {
        $self->_run_command($xrepo, 'clean', '-y');
        return 1;
    }

    method add_repo ($name, $url, $branch = undef) {
        my @cmd = ($xrepo, 'add-repo', $name, $url);
        push @cmd, $branch if defined $branch;
        $self->_run_command(@cmd);
        return 1;
    }

    method remove_repo ($name) {
        $self->_run_command($xrepo, 'remove-repo', $name);
        return 1;
    }

    method update_repo ($name = undef) {
        my @cmd = ($xrepo, 'update-repo');
        push @cmd, $name if defined $name;
        $self->_run_command(@cmd);
        return 1;
    }

    # ============================================================================
    # INTERNAL HELPERS
    # ============================================================================
    method _build_cli_options ($opts) {
        my @args;
        push @args, '-p', $opts->{plat} if $opts->{plat};
        push @args, '-a', $opts->{arch} if $opts->{arch};
        push @args, '-m', $opts->{mode} if $opts->{mode};
        push @args, '-k', ($opts->{kind} // 'shared');
        push @args, '--toolchain=' . $opts->{toolchain} if $opts->{toolchain};
        if (defined $opts->{configs}) {
            my $cfg = $opts->{configs};
            if (ref $cfg eq 'HASH') {
                $cfg = join(',', map {"$_=$cfg->{$_}"} sort keys %$cfg);
            }
            push @args, "--configs=$cfg";
        }
        if (defined $opts->{includes}) {
            my $inc = $opts->{includes};
            if (ref $inc eq 'ARRAY') {
                $inc = join(',', @$inc);
            }
            push @args, "--includes=$inc";
        }
        return @args;
    }

    method _run_command (@cmd) {
        say "Alien::Xrepo executing: @cmd" if $verbose;
        my ( $stdout, $stderr, @result ) = capture { system(@cmd) };
        my $exit_code = $result[0];

        if ( $exit_code == -1 ) {
            croak "Alien::Xrepo: Failed to execute command: $!\nCommand: @cmd";
        }
        elsif ( $exit_code & 127 ) {
            croak sprintf "Alien::Xrepo: Command died with signal %%d, %%s coredump\nCommand: @cmd", ( $exit_code & 127 ), ( $exit_code & 128 ) ? 'with' : 'without';
        }

        $exit_code >>= 8;

        if ($verbose) {
            print STDOUT $stdout if defined $stdout;
            print STDERR $stderr if defined $stderr;
        }
        if ( $exit_code != 0 ) {
            croak "Alien::Xrepo command failed (Exit $exit_code): @cmd\nStdout:\n$stdout\nStderr:\n$stderr";
        }
        return $stdout;
    }

    method _apply_backspace_characters ($str) {
        my $result = '';
        for my $c (split //, $str) {
            if ($c eq "\b") {
                substr($result, -1) = '' if length $result;
            }
            else {
                $result .= $c;
            }
        }
        return $result;
    }

    method _process_info ($meta) {
        my $libfiles = $meta->{libfiles}    // [];
        my $incdirs  = $meta->{includedirs} // [];
        my $linkdirs = $meta->{linkdirs}    // [];
        my $bindirs  = $meta->{bindirs}     // [];
        my $kind     = $meta->{kind}        // 'shared';

        my $runtime_lib;
        if ($^O eq 'MSWin32') {
            ($runtime_lib) = grep {/\.dll$/i} @$libfiles;
            unless ($runtime_lib) {
                my ($imp_lib) = grep {/\.lib$/i} @$libfiles;
                if ($imp_lib) {
                    my $lib_path = path($imp_lib);
                    my $basename = $lib_path->basename(qr/\.lib$/i);
                    my @search_dirs = (@$bindirs, $lib_path->parent->parent->child('bin'), $lib_path->parent->sibling('bin'));
                    for my $dir (@search_dirs) {
                        next unless -d $dir;
                        my $d = path($dir);
                        my $try = $d->child("$basename.dll");
                        if ($try->exists) { $runtime_lib = $try->stringify; last; }
                        my ($fuzzy) = grep { /^$basename/i && /\.dll$/i } map { $_->basename } $d->children;
                        if ($fuzzy) { $runtime_lib = $d->child($fuzzy)->stringify; last; }
                    }
                }
            }
        }
        elsif ($^O eq 'darwin') {
            ($runtime_lib) = grep {/\.dylib$/i} @$libfiles;
            $runtime_lib //= grep {/\.so$/i} @$libfiles;
        }
        else {
            ($runtime_lib) = grep {/\.so(\.|-|\d|$)/} @$libfiles;
        }

        if (!$runtime_lib && @$libfiles) {
            $runtime_lib = $libfiles->[0]; # Fallback to first file (likely static)
        }

        return Alien::Xrepo::PackageInfo->new(
            includedirs => $incdirs,
            libfiles    => $libfiles,
            libpath     => $runtime_lib,
            linkdirs    => $linkdirs,
            links       => $meta->{links}    // [],
            license     => $meta->{license},
            shared      => $meta->{shared}   // 0,
            static      => $meta->{static}   // 0,
            version     => $meta->{version},
            bindirs     => $bindirs,
        );
    }
}

class Alien::Xrepo::PackageInfo {
    use Path::Tiny;
    field $includedirs : param : reader;
    field $libfiles    : param : reader;
    field $libpath     : param : reader //= undef;
    field $linkdirs    : param : reader //= [];
    field $links       : param : reader //= [];
    field $license     : param : reader //= undef;
    field $shared      : param : reader //= 0;
    field $static      : param : reader //= 0;
    field $version     : param : reader //= undef;
    field $bindirs     : param : reader //= [];

    method bin_dirs () { @$bindirs }

    method affix ( $name, $args, $ret ) {
        require Affix;
        return Affix::affix( $self->libpath, $name, $args, $ret );
    }

    method find_header ($filename) {
        for my $dir (@$includedirs) {
            my $p = path($dir)->child($filename);
            return $p->stringify if $p->exists;
        }
        return undef;
    }
}
1;
__END__

=head1 NAME

Alien::Xrepo - Locate, Install, and Inspect packages via xrepo

=head1 SYNOPSIS

    use Alien::Xrepo;

    my $repo = Alien::Xrepo->new;

    # Install a package
    my $pkg = $repo->install('libpng');

    # Inspect the package
    say $pkg->version;
    say $pkg->libpath;
    say $pkg->find_header('png.h');

=head1 DESCRIPTION

C<Alien::Xrepo> is a wrapper around the C<xrepo> package manager (part of the Xmake ecosystem).
It allows you to easily manage C/C++ dependencies from Perl.

=head1 METHODS

=head2 C<new( %options )>

    my $repo = Alien::Xrepo->new( verbose => 1 );

Supported options:

=over 4

=item * C<verbose> - Enable verbose output.

=item * C<xrepo> - Path to the C<xrepo> executable (defaults to the one provided by L<Alien::Xmake>).

=back

=head2 C<install( $package, $version, %options )>

Installs a package and returns an L<Alien::Xrepo::PackageInfo> object.

    $repo->install('zlib', '1.2.11', kind => 'static');

Options for C<install>:

=over 4

=item * C<plat> - Platform (e.g., 'iphoneos', 'android').

=item * C<arch> - Architecture (e.g., 'arm64', 'x86_64').

=item * C<mode> - Mode ('debug' or 'release').

=item * C<kind> - 'shared' (default) or 'static'.

=item * C<configs> - Hashref of custom build configurations.

=back

=head2 C<uninstall( $package, %options )>

Uninstalls a package.

=head2 C<search( $query )>

Searches for packages.

=head2 C<clean()>

Cleans the xrepo cache.

=head2 C<add_repo( $name, $url, $branch )>

Adds a custom xrepo repository.

=head2 C<remove_repo( $name )>

Removes an xrepo repository.

=head2 C<update_repo( $name )>

Updates repositories.

=head1 PACKAGE INFO METHODS

The object returned by C<install> provides the following methods:

=over 4

=item * C<version()> - Version of the installed package.

=item * C<libpath()> - Absolute path to the primary runtime library (DLL/SO/DYLIB) or static library.

=item * C<affix($name, $args, $ret)> - Wrapper around L<Affix/affix>. Automatically uses C<libpath()>.

    my $png_sig_cmp = $pkg->affix('png_sig_cmp', ['string', 'size_t', 'size_t'] => 'int');
    my $is_png = $png_sig_cmp->("...", 0, 8);

=item * C<includedirs()> - List of include directories.

=item * C<find_header($filename)> - Returns the absolute path to a header file if found.

=item * C<libfiles()> - List of all library files provided by the package.

=item * C<license()> - License name.

=back

=head1 AUTHOR

Sanko Robinson <sanko@cpan.org>

=head1 LICENSE

Copyright (C) Sanko Robinson.

This library is free software; you can redistribute it and/or modify it under the terms found in the Artistic License 2.