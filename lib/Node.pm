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

has is_joinable => ( # true iff this node has two children which are both leaves
		    isa => 'Bool',
		    is => 'rw',
		    default => 0,
		   );

has sibling => ( # sibling node; a pair of sibling nodes have the same parent
		isa => 'Maybe[Object]',
		is => 'rw',
		default => undef,
	       );

sub BUILD {
  my $self = shift;
  #  $self->tree()->unikey_node()->{$self->unique_key()} = $self;
}

sub split_post_prob_ratio{
  my $self = shift;
  my $q = shift;

}

sub add_point{
  my $self = shift;
  my $p_index = shift;
  push @{$self->p_indices()}, $p_index;
}

sub split_node{			# create pair of nodes
  my $self = shift;
  my $q_ratio = shift;
  my @l_q_indices =  @{$self->q_indices()};
  my $split_q_index = shift @l_q_indices;
  my @r_q_indices = @l_q_indices;
  my $tree = $self->tree();
  my $l_node = Node->new( { is_leaf => 1, q_indices => \@l_q_indices } );
  my $r_node = Node->new( { is_leaf => 1, q_indices => \@r_q_indices } );

  my $data_obj = $self->tree()->data();
  for my $p_index (@{$self->p_indices()}) {
    if ($data_obj->answer($p_index, $split_q_index) == 0) {
      $l_node->add_point($p_index);
    } else {
      $r_node->add_point($p_index);
    }
  }

  my $n = scalar @{$self->p_indices()};
  my $m_l = scalar @{$l_node->p_indices()};
  my $m_r =  scalar @{$r_node->p_indices()};
my $N = $self->tree()->N();
my $K = $self->tree()->n_leaves();

# ratios are split over join
my $pppr = pp_prob_ratio_split_over_joined($n, $m_l, $m_r, $N, $K);
  if($pppr >= $q_ratio or rand() < $pppr/$q_ratio){ # ACCEPT, and make the split.
    
  print STDERR "split accepted. n_leaves post-split: ", $K+1, ". n, m, n-m: $n $m_l $m_r \n";

  # connect new nodes to tree.
 
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
}

}

sub join_nodes{ # remove the two leaf-node children of this (joinable) node, leaving it as a leaf.
  my $self = shift;
  my $q_ratio = shift; # split over joined
  my $L = $self->left();
  my $R = $self->right();
  $self->left(undef);
  $self->right(undef);
  $self->is_leaf(1);
print STDERR $self->tree()->newick(), "\n";
  my $n = scalar @{$self->p_indices()};
  my $m_l = scalar @{$L->p_indices()};
  my $m_r =  scalar @{$R->p_indices()};
  my $N = $self->tree()->N();
  my $K = $self->tree()->n_leaves() - 1; # number of leaves in joined state

my $ratio =   $q_ratio/pp_prob_ratio_split_over_joined($n, $m_l, $m_r, $N, $K);
  if($ratio >= 1 or rand() < $ratio){ # ACCEPT, and make the split.

  delete $self->tree()->leaf_unikeys()->{$L->unique_key()};
  delete $self->tree()->leaf_unikeys()->{$R->unique_key()};
  $self->tree()->leaf_unikeys()->{$self->unique_key()} = 1;
  $self->tree()->increment_n_leaves(-1);
  delete $self->tree()->unikey_node()->{$L->unique_key()};
  delete $self->tree()->unikey_node()->{$R->unique_key()};
  delete $self->tree()->joinable_unikeys()->{$self->unique_key()};
  if (! $self->is_root()) {
    if ($self->sibling()->is_leaf()) { 
      $self->parent()->is_joinable(1);
      $self->tree()->joinable_unikeys()->{$self->parent()->unique_key()} = 1;
    }
  }
}
}

sub newick{
  my $self = shift;
  my $n = scalar @{$self->p_indices()};
  if ($self->is_leaf()) {
    #   return $self->unique_key() . ":" . $n;
    return "$n:1";
  } else {
    #   return '(' . $self->left()->newick() . ',' . $self->right()->newick() . '):' . $n;
    return '(' . $self->left()->newick() . ',' . $self->right()->newick() . '):1';
  }
}

sub pp_prob_ratio_split_over_joined{ # ratio of posterior probability in split state to p.p. in unsplit state
# at present prior probs are just 1.
  my $n = shift;	       # scalar @{$self->p_indices()};
  my $m_l = shift;	       # scalar @{$self->left()->p_indices()};
  my $m_r =  shift;	       #scalar @{$self->right()->p_indices()};
  die "n, m_l, m_l inconsistent, in pp_prob_ratio: $n $m_l $m_r.\n" if($n != $m_l + $m_r);
  my $N = shift;		# $self->tree()->N();

  my $K = shift; #($self->is_leaf())? $self->tree()->n_leaves() : $self->tree()->n_leaves() - 1;

  # ratio = 1/((N+K)*K)  *  2^n/(n choose m) this is p(split)/p(unsplit)
  # N is total number of data points, K is (unsplit) number of leaves.
  my $ratio = 2**$n/n_choose_k($n, $m_l); 
  $ratio /= (($N + $K) * $K);
  $ratio *= prior_prob_ratio_split_over_joined($K);
  return $ratio;
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

sub prior_prob_ratio_split_over_joined{
my $K = shift;
return 2*(2*$K + 1)/($K + 1); # prior_prob(K) proportional to C_K (catalan number)
}

1;
