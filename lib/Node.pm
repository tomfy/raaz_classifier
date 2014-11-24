package Node;
use strict;
use Moose;
use namespace::autoclean;
use Carp;
use List::Util qw ( min max sum );

# a node with parent, and left and right children
# 
has tree => (			# the tree to which the node belongs
	     isa => 'Maybe[Object]',
	     is => 'rw',
	    );

has unique_key => ( # bits represent L and R branches in tree (0 => L, 1 => 1; more significant bits higher in tree), the root is
		   # 1, it L child is 10, R child is 11, etc.
		   # e.g. 10010 is L child of R child of L child of L child of root. (the initial 1 represents the root).
		   isa => 'Int',
		   is => 'rw',
		   default => -1
		  );

has is_root => (
		isa => 'Bool',
		is => 'ro',
		default => 0
	       );

has parent => (			# parent node
	       isa     => 'Maybe[Object]',
	       is      => 'rw',
	       default => undef
	      );

has left => (			# left child node
	     isa     => 'Maybe[Object]',
	     is      => 'rw',
	     default => undef
	    );

has right => (			# right child node
	      isa     => 'Maybe[Object]',
	      is      => 'rw',
	      default => undef
	     );

has p_indices => (		# indices of data points in this box
                  isa     => 'ArrayRef',
                  is      => 'rw',
                  default => sub { [] }
		 );

has q_indices => (		# indices of questions not used yet
		  isa     => 'ArrayRef',
                  is      => 'rw',
                  default => sub { [] }
		 );

has is_leaf => (
		isa => 'Bool',
		is => 'rw',
		default => 1,
	       );

has is_splittable => ( # node is splittable iff:
		      # 1) it's a leaf,
		      # 2) its q_indices array has > 0 elements,
		      # 3) its p_indices array has >= n_split_min_elements
		     isa => 'Bool',
		     is => 'rw',
		     default => 0,
);

has is_joinable => ( # true iff this node has two children which are both leaves
		    isa => 'Bool',
		    is => 'rw',
		    default => 0,
		   );

has sibling => ( # sibling node; a pair of sibling nodes have the same parent.
		isa => 'Maybe[Object]',
		is => 'rw',
		default => undef,
	       );

has population => ( # number of data point which fall into this box
		   isa => 'Int',
		   is => 'rw',
		   default => 0,
);

sub BUILD {
  my $self = shift;
  #  $self->tree()->unikey_node()->{$self->unique_key()} = $self;
#print "MCTree BUILD\n";
}

sub increment_population{
  my $self = shift;
  my $increment = shift;
  $increment = 1 if(!defined $increment);
  $self->population($self->population() + $increment);
};

sub split_population{ # arg is a q index; return 2 array refs with the p_indices of
  # the population split according to that q index
  my $self = shift;
  my $split_q_index = shift;
  my $data_obj = $self->tree()->data();
  my @l_p_indices = ();
  my @r_p_indices = ();
  for my $p_index (@{$self->p_indices()}) {
    if ($data_obj->answer($p_index, $split_q_index) == 0) {
      push @l_p_indices, $p_index;
    } else {
      push @r_p_indices, $p_index;
    }
  }
  return (\@l_p_indices, \@r_p_indices);
}

sub split_node_mcmc{			# create pair of nodes
  my $self = shift;
  my $q_ratio = shift;
  my @l_q_indices =  @{$self->q_indices()};
  my $split_q_index = shift @l_q_indices;
  my @r_q_indices = @l_q_indices;

  # if (1) {
    my  ($l_p_indices, $r_p_indices) = $self->split_population($split_q_index);

    my $n = scalar @{$self->p_indices()};
    my $m_l = scalar @$l_p_indices;
    my $m_r =  scalar @$r_p_indices;
    my $N = $self->tree()->N();
    my $K = $self->tree()->n_leaves();

    # ratios are split over join
    my $pp_ratio = posterior_prob_ratio_split_over_joined($n, $m_l, $m_r, $N, $K);
    my $random_number = rand();
    my $accept = ($pp_ratio >= $q_ratio or $random_number*$q_ratio < $pp_ratio); # ACCEPT, and make the split.
    if($accept){
      # store old tree info in tree accumulator (to be implemented)
      $self->tree()->weight(1); # reset tree weight to 1
    $self->split_node(\@l_q_indices, \@r_q_indices, $l_p_indices, $r_p_indices);
    }else{				# end of ACCEPTED branch
      $self->tree()->increment_weight(1);
    }
return ($accept, \@l_q_indices, \@r_q_indices, $l_p_indices, $r_p_indices);
}

sub join_nodes_mcmc{ # remove the two leaf-node children of this (joinable) node, leaving it as a leaf.
  my $self = shift;
  my $q_ratio = shift;		# split over joined
  my $L = $self->left();
  my $R = $self->right();
  #print "joining node: ", $self->unique_key(), "\n";
  if (! defined $L or ! defined $R) {
    die "attempting to join a node which has left or right child undef.\n";
  }

  my $n = scalar @{$self->p_indices()};
  my $m_l = scalar @{$L->p_indices()};
  my $m_r =  scalar @{$R->p_indices()};
  my $N = $self->tree()->N();
  my $K = $self->tree()->n_leaves() - 1; # number of leaves in joined state
  my $pp_ratio = posterior_prob_ratio_split_over_joined($n, $m_l, $m_r, $N, $K);
  #  my $ratio =   $q_ratio/pp_prob_ratio_split_over_joined($n, $m_l, $m_r, $N, $K);
  my $random_number = rand();
  #  if ($ratio >= 1 or $random_number < $ratio) { # ACCEPT
  my $accept = ($q_ratio >= $pp_ratio  or $random_number*$pp_ratio < $q_ratio);
  if ($accept) {	# ACCEPT the proposed join
    # store old tree info in tree accumulator (to be implemented)
    $self->tree()->weight(1);
    $self->join_nodes();
  }else{  # REJECT
    $self->tree()->increment_weight(1);
  }
  return $accept;
}

sub split_node{
  my $self = shift;
  my $lq_indices = shift;
  my $rq_indices = shift;
  my $lp_indices = shift;
  my $rp_indices = shift;
  my $tree = $self->tree();
  my $l_node = Node->new( { is_leaf => 1, q_indices => $lq_indices, p_indices => $lp_indices } );
  my $r_node = Node->new( { is_leaf => 1, q_indices => $rq_indices, p_indices => $rp_indices } ); 

  $self->left($l_node);		# make new nodes children of $self.
  $self->right($r_node);
  $l_node->parent($self);	# make $self parent of new nodes.
  $r_node->parent($self);
  $l_node->sibling($r_node);  # make new nodes siblings of each other.
  $r_node->sibling($l_node);

  $l_node->tree($tree); # make new nodes have same tree object as $self
  $r_node->tree($tree);

  # get a unique key for each of the new nodes, and
  my $L_unikey = $self->unique_key() * 2;
  my $R_unikey = $L_unikey + 1;
  $l_node->unique_key($L_unikey);
  $r_node->unique_key($R_unikey);
  $tree->unikey_node()->{$L_unikey} = $l_node;
  $tree->unikey_node()->{$R_unikey} = $r_node;
  $tree->leaf_unikeys()->{$L_unikey} = 1;
  $tree->leaf_unikeys()->{$R_unikey} = 1;

  $self->is_leaf(0);		# $self is no longer a leaf.
  delete $tree->leaf_unikeys()->{$self->unique_key()};
  $tree->increment_n_leaves(); # the total number of leaves has increased by 1

  $self->is_joinable(1); # $self is now joinable - i.e. both its children are leaves.
  $tree->joinable_unikeys()->{$self->unique_key()} = 1;

  if (! $self->is_root()) {
    $self->parent()->is_joinable(0); # parent of $self may or may not have been joinable before, but now it is not.
    delete $tree->joinable_unikeys()->{$self->parent()->unique_key()};
  }
  #print "tree after split: ", $tree->newick(), "\n";
}

sub join_nodes{
  my $self = shift;
 my $L = $self->left();
  my $R = $self->right();
  die "Attempted to join non-leaf nodes. \n" if(! ($L->is_leaf() and $R->is_leaf() ) );
  $self->left(undef);
  $self->right(undef);
  $self->is_leaf(1);
  #  print  "before join. tree: ", $self->tree()->newick(), ". j-uks: ", join(",", keys %{$self->tree()->joinable_unikeys()}), "\n";
  delete $self->tree()->leaf_unikeys()->{$L->unique_key()};
  delete $self->tree()->leaf_unikeys()->{$R->unique_key()};
  $self->tree()->leaf_unikeys()->{$self->unique_key()} = 1;
  $self->tree()->increment_n_leaves(-1);
  delete $self->tree()->unikey_node()->{$L->unique_key()};
  delete $self->tree()->unikey_node()->{$R->unique_key()};
  #  print "after joining1. joinable keys: ", join(", ", keys %{$self->tree()->joinable_unikeys()}), "\n";
  delete $self->tree()->joinable_unikeys()->{$self->unique_key()};
  #   print $self->tree()->newick(), "\n";
  #    print "after joining2. joinable keys: ", join(", ", keys %{$self->tree()->joinable_unikeys()}), "\n";
  if (! $self->is_root()) {
    if ($self->sibling()->is_leaf()) {
      $self->parent()->is_joinable(1);
      $self->tree()->joinable_unikeys()->{$self->parent()->unique_key()} = 1;
    }
  }
  # print "tree after join: ", $self->tree()->newick(), "\n";
}

sub newick{
  my $self = shift;
  my $n = scalar @{$self->p_indices()};
  if ($self->is_leaf()) {
  #     return $self->unique_key() . ":" . $n;
    return "$n:1";
  } else {
       return '(' . $self->left()->newick() . ',' . $self->right()->newick() . ')' . $n . ':' . 1;
   # return $self->unique_key() . '(' . $self->left()->newick() . ',' . $self->right()->newick() . '):' . "$n";
  }
}


#### Non-methods ####

sub posterior_prob_ratio_split_over_joined{ # ratio of posterior probability in split state to p.p. in unsplit state
  my $n = shift;	       # scalar @{$self->p_indices()};
  my $m_l = shift;	       # scalar @{$self->left()->p_indices()};
  my $m_r =  shift;	       # scalar @{$self->right()->p_indices()};
  die "n, m_l, m_l inconsistent, in posterior_prob_ratio: $n $m_l $m_r.\n" if($n != $m_l + $m_r);
  my $N = shift;		# $self->tree()->N();

  my $K = shift; #($self->is_leaf())? $self->tree()->n_leaves() : $self->tree()->n_leaves() - 1;

  # ratio = 1/((N+K)*K)  *  2^n/(n choose m) this is p(split)/p(unsplit)
  # N is total number of data points, K is (unsplit) number of leaves.
  my $ratio = 2**$n/n_choose_k($n, $m_l); 
  $ratio *= $K / ($N + $K) ;
  $ratio *= prior_prob_ratio_split_over_joined($K);
  return $ratio;
}

sub prior_prob_ratio_split_over_joined{
  my $K = shift;
  return  1/$K**0.25;
  # 1/( 2*(2*$K + 1)/($K + 1) ); # prior_prob(K) inv proportional to C_K (catalan number)
}


sub n_choose_k{
  my $n = shift;
  my $k = shift;
  $k = $n-$k if($k > $n-$k);
  my $result = 1;
  for my $i (1..$k) {
    $result *= ($n+1 - $i)/$i;
  }
  return $result;
}



1;
