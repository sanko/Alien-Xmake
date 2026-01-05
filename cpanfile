requires 'Path::Tiny';
requires 'perl', 'v5.40.0';
on configure => sub {
    requires 'Archive::Tar';
    requires 'CPAN::Meta';
    requires 'Capture::Tiny';
    requires 'File::Basename';
    requires 'File::Spec::Functions';
    requires 'File::Temp';
    requires 'File::Which';
    requires 'HTTP::Tiny';
    requires 'Module::Build', '0.4005';
    requires 'Path::Tiny';
};
on test => sub {
    requires 'Capture::Tiny';
    requires 'File::Temp';
    requires 'Test2::V0';
};
on develop => sub {
    requires 'CPAN::Uploader';
    requires 'Code::TidyAll';
    requires 'Code::TidyAll::Plugin::ClangFormat';
    requires 'Code::TidyAll::Plugin::PodTidy';
    requires 'Minilla';
    requires 'Perl::Tidy';
    requires 'Pod::Markdown::Github';
    requires 'Pod::Tidy';
    requires 'Software::License::Artistic_2_0';
    requires 'Test::CPAN::Meta';
    requires 'Test::MinimumVersion::Fast', '0.04';
    requires 'Test::PAUSE::Permissions',   '0.07';
    requires 'Test::Pod',                  '1.41';
    requires 'Test::Spellunker',           'v0.2.7';
    requires 'Version::Next';
};
