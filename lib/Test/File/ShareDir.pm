use 5.006;    # pragmas
use strict;
use warnings;

package Test::File::ShareDir;

our $VERSION = '1.001000';

# ABSTRACT: Create a Fake ShareDir for your modules for testing.

# AUTHORITY

=begin MetaPOD::JSON v1.1.0

{
    "namespace":"Test::File::ShareDir",
    "interface":"exporter"
}

=end MetaPOD::JSON

=cut

use File::ShareDir 1.00 qw();

sub import {
  my ( undef, %input_config ) = @_;

  require Test::File::ShareDir::TempDirObject;

  my ( $guard, $clearer );

  $guard   = delete $input_config{-guard}   if exists $input_config{-guard};
  $clearer = delete $input_config{-clearer} if exists $input_config{-clearer};

  my $tempdir_object = Test::File::ShareDir::TempDirObject->new( \%input_config );

  for my $module ( $tempdir_object->_module_names ) {
    $tempdir_object->_install_module($module);
  }

  for my $dist ( $tempdir_object->_dist_names ) {
    $tempdir_object->_install_dist($dist);
  }

  my $temp_path = $tempdir_object->_tempdir->stringify;

  unshift @INC, $temp_path;

  if ($guard) {
    require Scope::Guard;
    ${$guard} = Scope::Guard->new( _mk_clearer($temp_path) );
  }
  if ($clearer) {
    ${$clearer} = _mk_clearer($temp_path);
  }

  return 1;
}

## Hack: This prevents self-referencing memory leaks
## under debuggers.
sub _mk_clearer {
  my ($temp_path) = @_;
  return sub {
    ## no critic (Variables::RequireLocalizedPunctuationVars)
    @INC = grep { ref or $_ ne $temp_path } @INC;
  };
}

1;

=head1 SYNOPSIS

    use Test::More;

    # use FindBin; optional

    use Test::File::ShareDir
        # -root    => "$FindBin::Bin/../" # optional,
        # -clearer => \$variable          # optional,
        -share => {
            -module => { 'My::Module' => 'share/MyModule' }
            -dist   => { 'My-Dist'    => 'share/somefolder' }
        };

    use My::Module;

    use File::ShareDir qw( module_dir dist_dir );

    module_dir( 'My::Module' ) # dir with files from $dist/share/MyModule

    dist_dir( 'My-Dist' ) # dir with files from $dist/share/somefolder

=head1 DESCRIPTION

This module only has support for creating 'new' style share dirs and are NOT compatible with old File::ShareDirs.

For this reason, unless you have File::ShareDir 1.00 or later installed, this module will not be usable by you.

=head1 SIMPLE INTERFACE

Starting with version C<0.4.0>, there are a few extra interfaces you can use.

These will probably be more useful, and easier to grok, because they don't have a layer of
indirection in order to simultaneously support both C<Module> and C<Dist> C<ShareDir>'s.

=head2 Simple Exporter Interfaces

=head3 C<Test::File::ShareDir::Dist>

L<< C<Test::File::ShareDir::Dist>|Test::File::ShareDir::Dist >> provides a simple export interface
for making C<TempDir> C<ShareDir>'s from a given path:

    use Test::File::ShareDir::Dist { "Dist-Name" => "share/" };

This will automatically create a C<ShareDir> for C<Dist-Name> in a C<TempDir> based on the contents of C<CWD/share/>

See L<< C<Test::File::ShareDir::Dist>|Test::File::ShareDir::Dist >> for details.

=head3 C<Test::File::ShareDir::Module>

L<< C<Test::File::ShareDir::Module>|Test::File::ShareDir::Module >> provides a simple export interface
for making C<TempDir> C<ShareDir>'s from a given path:

    use Test::File::ShareDir::Module { "Module::Name" => "share/" };

This will automatically create a C<ShareDir> for C<Module::Name> in a C<TempDir> based on the contents of C<CWD/share/>

See L<< C<Test::File::ShareDir::Module>|Test::File::ShareDir::Module >> for details.

=head2 Simple Object Oriented Interfaces

=head3 C<Test::File::ShareDir::Object::Dist>

L<< C<Test::File::ShareDir::Object::Dist>|Test::File::ShareDir::Object::Dist >> provides a simple object oriented interface for
making C<TempDir> C<ShareDir>'s from a given path:

    use Test::File::ShareDir::Object::Dist;

    my $obj = Test::File::ShareDir::Object::Dist->new( dists => { "Dist-Name" => "share/" } );
    $obj->install_all_dists;
    $obj->register;

This will automatically create a C<ShareDir> for C<Dist-Name> in a C<TempDir> based on the contents of C<CWD/share/>

See L<< C<Test::File::ShareDir::Object::Dist>|Test::File::ShareDir::Object::Dist >> for details.

=head3 C<Test::File::ShareDir::Object::Module>

L<< C<Test::File::ShareDir::Object::Module>|Test::File::ShareDir::Object::Module >> provides a simple object oriented interface
for making C<TempDir> C<ShareDir>'s from a given path:

    use Test::File::ShareDir::Object::Module;

    my $obj = Test::File::ShareDir::Object::Module->new( modules => { "Module::Name" => "share/" } );
    $obj->install_all_modules;
    $obj->register;

This will automatically create a C<ShareDir> for C<Module::Name> in a C<TempDir> based on the contents of C<CWD/share/>

See L<< C<Test::File::ShareDir::Object::Module>|Test::File::ShareDir::Object::Module >> for details.

=head1 IMPORTING

=head2 -root

This parameter is the prefix the other paths are relative to.

If this parameter is not specified, it defaults to the Current Working Directory ( C<CWD> ).

In versions prior to C<0.3.0>, this value was mandatory.

The rationale behind using C<CWD> as the default value is as follows.

=over 4

=item * Most users of this module are likely to be using it to test distributions

=item * Most users of this module will be using it in C<$project/t/> to load files from C<$project/share/>

=item * Most C<CPAN> tools run tests with C<CWD> = $project

=back

Therefor, defaulting to C<CWD> is a reasonably sane default for most people, but where it is not it can
still be overridden.

  -root => "$FindBin::Bin/../" # resolves to project root from t/ regardless of Cwd.

=head2 -share

This parameter is mandatory, and contains a C<hashref> containing the data that explains what directories you want shared.

  -share =>  { ..... }

=head3 -module

C<-module> contains a C<hashref> mapping Module names to path names for module_dir style share dirs.

  -share => {
    -module => { 'My::Module' => 'share/mymodule/', }
  }

  ...

  module_dir('My::Module')

Notedly, it is a C<hashref>, which means there is a limitation of one share dir per module. This is simply because having more
than one share dir per module makes no sense at all.

=head3 -dist

C<-dist> contains a C<hashref> mapping Distribution names to path names for dist_dir style share dirs. The same limitation
applied to C<-module> applies here.

  -share => {
    -dist => { 'My-Dist' => 'share/mydist' }
  }
  ...
  dist_dir('My-Dist')

=head3 -clearer

C<-clearer>, may contain a reference to a variable. If specified, that variable will be set to a C<CodeRef> that will remove
the C<ShareDir> magic that we're injecting.

For instance:

  my $clearer;
  use Test::File::ShareDir
    -clearer => \$clearer,
    -share   => { -module => { 'My::Module' => 'share/MyModule' }};

  use File::ShareDir qw( module_dir );

  module_dir('My::Module')  # ok, because My::Module is now setup

  $clearer->();

  module_dir('My::Module') # probably fails .... or might not,
                           # either way, it defaults to using whatever is in your systems
                           # @INC

I<Since 1.001000>

=head3 -guard

B<EXPERIMENTAL>

B<NOTE:> This feature is presently partially broken under coverage testing with C<Devel::Cover> due to C<PL_savebegin>
breaking C<Scope::Guard>'s. There is a workaround using C<eval '\$guard'> however, but the extra effort required mostly negates
the ease of use of this feature, and using C<-clearer> is probably going to be simpler.

C<-guard>, may contain a reference to a variable. If specified, that variable will be set to a C<Scope::Guard> that will remove
the C<ShareDir> magic that we're injecting.

For instance:

  {
    my $guard;
    use Test::File::ShareDir
        -guard => eval '\$guard',     # EXPERIMENTAL, See note about eval
        -share => { -module => { 'My::Module' => 'share/MyModule' }};

    use File::ShareDir qw( module_dir );

    module_dir('My::Module')  # ok, because My::Module is now setup
  } # ShareDir is removed

  module_dir('My::Module') # probably fails .... or might not,
                           # either way, it defaults to using whatever is in your systems
                           # @INC


B<NOTE:> Observe in the above there is an apparently superfluous C<eval>. That code is presently necessary
to avoid making the C<BEGIN> block a C<closure> over C<$guard>, and thus makes the C<Scope::Guard> expire correctly.

I<Since 1.001000>

B<More Details:>

=over 4

=item * L<< C<Devel::Cover> issue 118 on C<Github>|https://github.com/pjcj/Devel--Cover/issues/118 >>

=item * L<< Related discussion on P5P|http://www.nntp.perl.org/group/perl.perl5.porters/2015/02/msg226031.html >>

=back

=cut
