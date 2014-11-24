package MCTree;
use strict;
use Moose;
use namespace::autoclean;
use Carp;
use List::Util qw ( min max sum );

use Data;
use Node;

use base 'Tree';


has repeatable => (
		   isa => 'Bool',
		   is => 'ro',
		   required => 1,
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

has weight => (
	       isa => 'Int',
	       is => 'rw',
	       default => 1,
);

has sum_tree => (
		 isa => 'Object',
		 is => 'rw',
		 required => 1,
);

has accumulator => ( # keys are node unique keys (e.g. 101001010 = LRLLRLRL, init '1' indicates root)
		    # values are sums (over markov chain) of beta's (box (i.e. leaf) probabilities)
		    isa => 'HashRef',
		    is => 'rw',
		    default => sub { {} },
);

sub BUILD {
  my $self = shift;
# parent class BUILD will be called before this one, so just do stuff
# specific to this class
  $self->root()->p_indices([0..$self->data()->N()-1]);
  $self->root()->q_indices([0..$self->data()->P()-1]);
}

sub info_string{
  my $self = shift;
  my $string = "N: " . $self->N() . "  ";
  $string .= "n leaves: " . $self->n_leaves() . "  ";
  $string .= "keys: [" . join(", ", sort {$a <=> $b} keys %{$self->unikey_node()} ) . "]";
  return $string;
}

sub increment_weight{
  my $self = shift;
  my $increment = shift || 1;
  $self->weight($self->weight() + $increment);
}

sub mcmc_step_split{		# split a leaf chosen at random
  my $self = shift;
  my @leaf_uks = keys %{$self->leaf_unikeys()};
#print "1repeatable? ", $self->repeatable(), "\n";
@leaf_uks = sort {$a <=> $b} @leaf_uks if($self->repeatable()); # this is to ensure runs are repeatable (if rng is seeded the same)
#  print STDERR "leaf uks: ", join(", ", @leaf_uks), "\n";
#  print STDERR $self->newick(), "\n";
  my $n_leaves = scalar @leaf_uks;

    my $rand_leaf_index = int (rand() * $n_leaves );
#print "In mcmc_step_split. rand leaf index: $rand_leaf_index \n";
my $uk_to_split = $leaf_uks[$rand_leaf_index];
#print "leaf uks: ", join(", ", @leaf_uks), "\n";
#print "rand leaf index: $rand_leaf_index; uk to split: $uk_to_split \n";
  my $leaf_to_split = $self->unikey_node()->{$uk_to_split };

  my @joinable_uks = keys %{$self->joinable_unikeys()};
  my $n_joinable_back = scalar @joinable_uks;
  $n_joinable_back++ if( $leaf_to_split->is_root()  or  ! $leaf_to_split->parent()->is_joinable() ); # this is the number of possible joins AFTER the split.
  my $q_split = 1/$n_leaves;
  my $q_join_back= 1/$n_joinable_back;
#  my $q_ratio_split_over_join = $q_split/$q_join;
#print "before split. leaf_uks: ", join(", ", @leaf_uks), " uk to split: ", $uk_to_split, "\n";
#print "before split. joinable_uks: ", join(", ", @joinable_uks), "\n";
  #print "tree before split: ", $self->newick(), "\n";

#print STDERR "in mcmc_step_split. n leaves: $n_leaves, n joinable (back): $n_joinable_back \n";
  my ($accept_split, $l_q_indices, $r_q_indices, $l_p_indices, $r_p_indices) = $leaf_to_split->split_node_mcmc($q_split/$q_join_back);
  if($accept_split){
# $leaf_to_split->split_node($l_q_indices, $r_q_indices, $l_p_indices, $r_p_indices);
 
  }else{
    $self->increment_weight(); 
  }
}

sub mcmc_step_join{ # choose a joinable node (parent of two leaves) at random, and join the two child leaves.
  my $self = shift;
  my @joinable_uks = keys %{$self->joinable_unikeys()};
#print "2repeatable?  ", $self->repeatable()? '1' : '0', "\n";
@joinable_uks = sort {$a <=> $b} @joinable_uks  if($self->repeatable());
#  print STDERR "joinable uks: ", join(", ", @joinable_uks), "\n";
  my $n_joinable = scalar @joinable_uks;
  # choose one of the joinable nodes uniformly at random:
   my $rand_join_index = int (rand() * $n_joinable );
#print "In mcmc_step_join. rand join index: $rand_join_index \n";
my $uk_to_join = $joinable_uks[$rand_join_index];
#print "rand join index: $rand_join_index; uk to join: $uk_to_join \n";
  my $node_to_join = $self->unikey_node()->{$uk_to_join};
  my $q_join = 1/$n_joinable;
my $n_leaves_back = $self->n_leaves() - 1; # number of leaves AFTER join (= possible splits at that point)
my $q_split_back = 1/$n_leaves_back;
#print STDERR "before join. joinable_uks: ", join(", ", @joinable_uks), "  uk to join: ", $uk_to_join, "\n";
#print STDERR "tree before join: ", $self->newick(), "\n";
#print STDERR "in mcmc_step_join. n leaves (back): $n_leaves_back, n joinable: $n_joinable \n";
#my $q_ratio_join_over_split = $q_joinable/$q_split;
  my $accept_join = $node_to_join->join_nodes_mcmc($q_split_back/$q_join);
  if($accept_join){
    # store the 
  }else{
    $self->increment_weight();
  }
}

sub add_tree{
  my $self = shift; # the tree to be added to
  my $tree = shift; # the tree to be added.
#  my $sum_tree = $self->
  my $NplusK = $tree->N() + $tree->n_leaves();
  for my $uk (keys $tree->leaf_unikeys()){
    my $source_node = $tree->unikey_node()->{$uk};
    my $address = $source_node->unique_key();
    if(! exists $self->unikey_node()->{$address}){ # after split the address may not be 
      # present in tree $self but parent address should be:
      my $parent_address = int($address / 2);
      if(! exists $self->unikey_node()->{$parent_address}){
	die "No node in tree has address: $parent_address. (When trying to add address $address to tree).\n";
      }else{
	my $parent_node =  $self->unikey_node()->{$parent_address};

	my $L = Node->new( { is_leaf => 1 } );
	$parent_node->left($L);
	$L->parent($parent_node);
	my $L_unikey = $parent_address * 2;
	$self->unikey_node()->{$L_unikey} = $L;
	my $R = Node->new( { is_leaf => 1 } );
	$parent_node->right($R);
	$R->parent($parent_node);
	my $R_unikey = $L_unikey + 1;
	$self->unikey_node()->{$R_unikey} = $R;

      }
    } 
    # now $address should be present in tree $self
    if (exists $self->unikey_node()->{$address}) {
      die "address $address STILL not present in target tree.\n";
    } else {
      my $target_node = $self->unikey_node()->{$address};
      $target_node->increment_population($tree->weight()*($source_node->population() + 1)); 
    }
  }				# loop over leaves
  $self->N($self->N() + $NplusK);
}
1;
