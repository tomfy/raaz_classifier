package Data;
use strict;
use Moose;
use namespace::autoclean;
use Carp;
use List::Util qw ( min max sum );

has data_source_filename => (
			     isa => 'Str',
			     is => 'ro',
			     required => 1
			    );

has data => (
	     isa => 'ArrayRef[ArrayRef[Bool]]',
	     is => 'rw',
	    );

has N => ( # number of data points
	  isa => 'Int',
	  is => 'rw',
	  );

has P => ( # number of binary answers
	  isa => 'Int',
	  is => 'rw',
);

sub BUILD {
  my $self = shift;
  my $datafilename = $self->data_source_filename();
  open my $fh_in, "<", "$datafilename"  or die "Couldn't open file $datafilename for reading.\n";
  my @data_points = ();
  my $P = -1;
  while (<$fh_in>) {
    s/\s+//g; # remove all whitespace
    my @qs = split('', $_);
    push @data_points, \@qs;
    $P = scalar @qs;
  }
  $self->N(scalar @data_points);
  $self->P($P);
  $self->data(\@data_points);
}

sub data_as_string{
  my $self = shift;
  my $string = '';
  for my $answers (@{$self->data()} ){
    $string .= join("", @$answers) . "\n";
}
  return $string;
}

sub data_point{		   # return the data point with index $p_index
  my $self = shift;
  my $p_index = shift;
  return $self->data()->[$p_index];
}

sub answer{ # return the answer with index $q_index of the data point with index $p_index
  my $self = shift;
  my $p_index = shift;
  my $q_index = shift;
  return $self->data_point($p_index)->[$q_index];
}

__PACKAGE__->meta->make_immutable;

1;
