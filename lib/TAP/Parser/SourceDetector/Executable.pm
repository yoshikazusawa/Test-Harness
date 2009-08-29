package TAP::Parser::SourceDetector::Executable;

use strict;
use vars qw($VERSION @ISA);

use TAP::Parser::SourceDetector    ();
use TAP::Parser::SourceFactory     ();
use TAP::Parser::Iterator::Process ();

@ISA = qw(TAP::Parser::SourceDetector);

# Causes problem on MacOS and shouldn't be necessary anyway
#$SIG{CHLD} = sub { wait };

TAP::Parser::SourceFactory->register_detector(__PACKAGE__);

=head1 NAME

TAP::Parser::SourceDetector::Executable - Stream output from an executable TAP source

=head1 VERSION

Version 3.18

=cut

$VERSION = '3.18';

=head1 SYNOPSIS

  use TAP::Parser::SourceDetector::Executable;
  my $source = TAP::Parser::SourceDetector::Executable->new;
  my $stream = $source->raw_source(['/usr/bin/ruby', 'mytest.rb'])->get_stream;

=head1 DESCRIPTION

This is an I<executable> L<TAP::Parser::SourceDetector> class.  It has 2 jobs:

1. Figure out if the I<raw> source it's given is actually an executable file.
See L<TAP::Parser::SourceFactory> for more details.

2. Takes a command and hopefully converts into an iterator.

Unless you're writing a plugin or subclassing L<TAP::Parser>, you probably
won't need to use this module directly.

=head1 METHODS

=head2 Class Methods

=head3 C<new>

 my $source = TAP::Parser::SourceDetector::Executable->new;

Returns a new C<TAP::Parser::SourceDetector::Executable> object.

=cut

# new() implementation supplied by TAP::Object

sub _initialize {
    my ( $self, @args ) = @_;
    $self->SUPER::_initialize(@args);

    # TODO: does this really need to be done here?
    _autoflush( \*STDOUT );
    _autoflush( \*STDERR );

    return $self;
}

=head3 C<can_handle>

=cut

sub can_handle {
    my ( $class, $src ) = @_;
    my $meta = $src->meta;

    if ( $meta->{is_file} ) {
        my $file = $meta->{file};

        # Note: we go in low so we can be out-voted
        return 0.8 if $file->{lc_ext} eq '.sh';
        return 0.8 if $file->{lc_ext} eq '.bat';
        return 0.7 if $file->{execute};
    }
    elsif ( $meta->{is_hash} ) {
        return 0.99 if $src->raw->{exec};
    }

    return 0;
}

=head3 C<make_iterator>

=cut

sub make_iterator {
    my ( $class, $src ) = @_;
    my $meta   = $src->meta;
    my $source = $class->new;

    $source->merge( $src->merge );

    if ( $meta->{is_hash} ) {
        $source->raw_source( $src->raw->{exec} );
    }
    elsif ( $meta->{is_file} ) {
        $source->raw_source([ $src->raw ]);
    }
    else {
        $source->raw_source( $src->raw );
    }

    return $source->get_stream;
}

##############################################################################

=head2 Instance Methods

=head3 C<raw_source>

 my $source = $source->raw_source;
 $source->raw_source(['./some_prog some_test_file']);

 # or
 $source->raw_source(['/usr/bin/ruby', 't/ruby_test.rb']);

Getter/setter for the raw source.  This should generally consist of an array
reference of strings which, when executed via L<&IPC::Open3::open3|IPC::Open3>,
should return a filehandle which returns successive rows of TAP.  C<croaks> if
it doesn't get an arrayref.

=cut

sub raw_source {
    my $self = shift;

    return $self->SUPER::raw_source unless @_;

    my $ref = ref $_[0];
    if ( !defined($ref) ) {
        ;    # fall through
    }
    elsif ( $ref eq 'ARRAY' ) {
        return $self->SUPER::raw_source( $_[0] );
    }
    elsif ( $ref eq 'HASH' ) {
        my $exec = $_[0]->{exec};
        return $self->SUPER::raw_source($exec);
    }

    $self->_croak(
        'Argument to &raw_source must be an array reference or hash reference'
    );
}

##############################################################################

=head3 C<get_stream>

 my $stream = $source->get_stream( $iterator_maker );

Returns a L<TAP::Parser::Iterator> stream of the output generated by executing
C<raw_source>.  C<croak>s if there was no command found.

Must be passed an object that implements a C<make_iterator> method.
Typically this is a TAP::Parser instance.

=cut

sub get_stream {
    my ( $self, $factory ) = @_;
    my @command = $self->_get_command
      or $self->_croak('No command found!');

    return TAP::Parser::Iterator::Process->new(
        {   command => \@command,
            merge   => $self->merge
        }
    );
}

sub _get_command { return @{ shift->raw_source || [] } }

# Turns on autoflush for the handle passed
sub _autoflush {
    my $flushed = shift;
    my $old_fh  = select $flushed;
    $| = 1;
    select $old_fh;
}

1;

=head1 SUBCLASSING

Please see L<TAP::Parser/SUBCLASSING> for a subclassing overview.

=head2 Example

  package MyRubySourceDetector;

  use strict;
  use vars '@ISA';

  use Carp qw( croak );
  use TAP::Parser::SourceDetector::Executable;

  @ISA = qw( TAP::Parser::SourceDetector::Executable );

  # expect $source->(['mytest.rb', 'cmdline', 'args']);
  sub raw_source {
    my ($self, $args) = @_;
    my ($rb_file) = @$args;
    croak("error: Ruby file '$rb_file' not found!") unless (-f $rb_file);
    return $self->SUPER::raw_source(['/usr/bin/ruby', @$args]);
  }

=head1 SEE ALSO

L<TAP::Object>,
L<TAP::Parser>,
L<TAP::Parser::SourceDetector>,
L<TAP::Parser::SourceDetector::Perl>,
L<TAP::Parser::SourceDetector::File>,
L<TAP::Parser::SourceDetector::Handle>,
L<TAP::Parser::SourceDetector::RawTAP>

=cut
