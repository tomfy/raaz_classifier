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

has leaf_unikeys => (			# keys are unique_keys of leaf nodes.
	       isa => 'HashRef',
	       is => 'rw',
	       default => sub{ {} },
	      );

has joinable_unikeys => (	     # keys are unique_keys of joinable nodes.
		  isa => 'HashRef',
		  is => 'rw',
		  default => sub{ {} }
		 );

has data => (		# this would be an object with N data points, 
	     # each consisting of an array of p elements, each of which is 0 or 1
	     isa => 'Object',
	     is => 'ro',
	     required => 1,
	    );

has N => (
	  isa => 'Int',
	  is => 'ro',
	  default => undef
	 );

has unikey_node => (
		    isa => 'HashRef[Object]',
		    is => 'rw',
		    default => sub { {} },
		   );

around BUILDARGS => sub {
  my $orig = shift;
  my $class = shift;
  if ( @_ == 1) {		# just one argument
    my $arg = $_[0];
    if ( ref $arg ) { # arguments is a ref, should be {data => $data_obj}
      if (exists $arg->{data}) {
	my $data_obj = $arg->{data};
	my $N = $data_obj->N();
	return {data => $data_obj, N => $N};
      } else {
	die "No data object supplied to Tree constructor. \n";
      }
    } else {
      return $class->$orig(@_);
    }
  } else {
    return $class->$orig(@_);
  }
};

sub BUILD {
  my $self = shift;

  my $root_unikey = 1;
  $self->root( Node->new( { tree => $self, is_root => 1, unique_key => $root_unikey } ) );
  $self->unikey_node()->{$root_unikey} = $self->root();
  $self->leaf_unikeys()->{$root_unikey} = 1;

  $self->root()->p_indices([0..$self->data()->N()-1]);
  $self->root()->q_indices([0..$self->data()->P()-1]);
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
  my $string = "N: " . $self->N() . "  ";
  $string .= "n leaves: " . $self->n_leaves() . "  ";
  $string .= "keys: [" . join(", ", keys %{$self->unikey_node()} ) . "]";
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

sub mcmc_step_split{		# split a leaf chosen at random
  my $self = shift;
  my @leaf_uks = keys %{$self->leaf_unikeys()};
#  print STDERR "leaf uks: ", join(", ", @leaf_uks), "\n";
#  print STDERR $self->newick(), "\n";
  my $n_leaves = scalar @leaf_uks;

  #  my $runk = int (rand() * $n_leaves );
my $uk_to_split = $leaf_uks[int (rand() * $n_leaves )];
  my $leaf_to_split = $self->unikey_node()->{$uk_to_split };

  my @joinable_uks = keys %{$self->joinable_unikeys()};
  my $n_joinable_back = scalar @joinable_uks;
  $n_joinable_back++ if(! $leaf_to_split->parent()->is_joinable()); # this is the number of possible joins AFTER the split.
  my $q_split = 1/$n_leaves;
  my $q_join_back= 1/$n_joinable_back;
#  my $q_ratio_split_over_join = $q_split/$q_join;
#print "before split. leaf_uks: ", join(", ", @leaf_uks), " uk to split: ", $uk_to_split, "\n";
#print "before split. joinable_uks: ", join(", ", @joinable_uks), "\n";
  #print "tree before split: ", $self->newick(), "\n";

#print STDERR "in mcmc_step_split. n leaves: $n_leaves, n joinable (back): $n_joinable_back \n";
  $leaf_to_split->split_node($q_split/$q_join_back);
}

sub mcmc_step_join{ # choose a joinable node (parent of two leaves) at random, and join the two child leaves.
  my $self = shift;
  my @joinable_uks = keys %{$self->joinable_unikeys()};
#  print STDERR "joinable uks: ", join(", ", @joinable_uks), "\n";
  my $n_joinable = scalar @joinable_uks;
  # choose one of the joinable nodes uniformly at random:
my $uk_to_join = $joinable_uks[int (rand() * $n_joinable )];
  my $node_to_join = $self->unikey_node()->{$uk_to_join};
  my $q_join = 1/$n_joinable;
my $n_leaves_back = $self->n_leaves() - 1; # number of leaves AFTER join (= possible splits at that point)
my $q_split_back = 1/$n_leaves_back;
#print STDERR "before join. joinable_uks: ", join(", ", @joinable_uks), "  uk to join: ", $uk_to_join, "\n";
#print STDERR "tree before join: ", $self->newick(), "\n";
#print STDERR "in mcmc_step_join. n leaves (back): $n_leaves_back, n joinable: $n_joinable \n";
#my $q_ratio_join_over_split = $q_joinable/$q_split;
  $node_to_join->join_nodes($q_split_back/$q_join);
}

1;
