package Tree;
use strict;
use Moose;
use namespace::autoclean;
use Carp;
use List::Util qw ( min max sum );

use Data;
use Node;


has root => (
	     isa     => 'Maybe[Object]',
	     is      => 'rw',
	     default => undef
	    );

has n_leaves => (
		 isa => 'Int',
		 is => 'rw',
		 default => 1
		);

has leaf_unikeys => (		     # keys are unique_keys of leaf nodes.
	       isa => 'HashRef',
	       is => 'rw',
	       default => sub{ {} },
	      );

has unikey_node => (
		    isa => 'HashRef[Object]',
		    is => 'rw',
		    default => sub { {} },
		   );

sub BUILD {
  my $self = shift;
  my $root_unikey = 1;
  $self->root( Node->new( { tree => $self, is_root => 1, unique_key => $root_unikey } ) );
  $self->unikey_node()->{$root_unikey} = $self->root();
  $self->leaf_unikeys()->{$root_unikey} = 1;
}

sub check{ # do some checks
my $self = shift;
my $n_leaves_ok = $self->n_leaves() == scalar keys %{$self->leaf_unikeys()};
# print STDERR "n leaves: ", $self->n_leaves(), "  ", scalar keys %{$self->leaf_unikeys()}, "\n";

my $OK = $n_leaves_ok;
die "problem with n_leaves: ", $self->n_leaves(), "  ", scalar keys %{$self->leaf_unikeys()}, ".\n" if(!$n_leaves_ok);
return $OK;
}

sub info_string{
  my $self = shift;
 # my $string = "N: " . $self->N() . "  ";
  my $string = "n leaves: " . $self->n_leaves() . "  ";
  $string .= "keys: [" . join(", ", sort {$a <=> $b} keys %{$self->unikey_node()} ) . "]";
  return $string;
}

sub increment_n_leaves{
  my $self = shift;
  my $increment = shift || 1; 
  my $new_n_leaves = $self->n_leaves() + $increment;
  $self->n_leaves($new_n_leaves);
}

sub newick{
  my $self = shift;
  return $self->root()->newick();
}

1;
