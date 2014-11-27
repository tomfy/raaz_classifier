package Tree;
use strict;
use Moose;
use namespace::autoclean;
use Carp;
use Carp::Assert; # or no Carp::Assert to turn off assertions.
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

sub check{			# do some checks
  my $self = shift;
  my $n_leaves_ok = $self->n_leaves() == scalar keys %{$self->leaf_unikeys()};
  my $leaf_bad_count = 0;
  # print STDERR "n leaves: ", $self->n_leaves(), "  ", scalar keys %{$self->leaf_unikeys()}, "\n";
  while (my ($uk, $node) = each  %{$self->unikey_node()}) {
    my $is_leaf = $node->is_leaf();
    if ($node->is_leaf()) {
      $leaf_bad_count++ if(! exists $self->leaf_unikeys()->{$uk});
    } else {
      $leaf_bad_count++ if( exists $self->leaf_unikeys()->{$uk});
    }
  }

  my $OK = ($n_leaves_ok and ($leaf_bad_count == 0));
  if (! $OK) {
    print STDERR "In Tree::check. Problem with leaves: ", $self->n_leaves(), "  ", scalar keys %{$self->leaf_unikeys()}, " leaf bad count: $leaf_bad_count.\n";
  }
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

__PACKAGE__->meta->make_immutable;

1;
