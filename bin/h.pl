#!/usr/bin/perl -w
use strict;
use lib '/home/tomfy/Raaz/lib';
use Carp::Assert;	  # or no Carp::Assert to turn off assertions.
use Data;
use Tree;
use MCTree;
use Node;

my $rand_seed = srand(12345);
print STDERR "# RNG seed: $rand_seed \n";

my $input_data_filename = shift or die "No data file given.\n";
my $n_mcmc_steps = shift || 200;
my $repeatable = shift || 0;	#

# read data from file, construct Data object:
my $data_obj = Data->new( { data_source_filename => $input_data_filename } );

my $sum_tree = Tree->new();

# construct MCTree object
my $mc_tree =MCTree->new( { data => $data_obj, N => $data_obj->N(), repeatable => $repeatable, sum_tree => $sum_tree }); #$repeatable } );
print "# init mc_tree info: ", $mc_tree->info_string(), "\n";

# generate an initial tree:
# split the root:
#rand();
my ($pp_ratio, $l_q_indices, $r_q_indices, $l_p_indices, $r_p_indices) = $mc_tree->root()->split_node_pp_ratio();
$mc_tree->root()->split_node($l_q_indices, $r_q_indices, $l_p_indices, $r_p_indices);
print "# after splitting root: \n";
print "# ", $mc_tree->info_string(), "\n";
print "# ", $mc_tree->newick(), "\n";

# split each leaf:
my @leaf_ukeys = keys %{$mc_tree->leaf_unikeys()};
for my $a_leaf_unikey (@leaf_ukeys) {
  my $leaf_node = $mc_tree->unikey_node()->{$a_leaf_unikey};
  #rand();
  ($pp_ratio, $l_q_indices, $r_q_indices, $l_p_indices, $r_p_indices) = $leaf_node->split_node_pp_ratio();
  $leaf_node->split_node($l_q_indices, $r_q_indices, $l_p_indices, $r_p_indices);
}
print "# after splitting both children of root: \n";
print "# ", $mc_tree->info_string(), "\n";
print "# ", $mc_tree->newick(), "\n";
print "# \n";
assert($mc_tree->check(), 'Tree check after splitting.') if DEBUG;

# print "# leaf addresses: ", join(", ", sort {$a<=>$b} @leaf_ukeys), "\n";
for my $a_leaf_unikey (@leaf_ukeys) {
  my $leaf_node = $mc_tree->unikey_node()->{$a_leaf_unikey};
  #rand();
  $leaf_node->join_nodes();
}
print "# after joining. \n";
print "# ", $mc_tree->info_string(), "\n";
print "# ", $mc_tree->newick(), "\n";
assert($mc_tree->check(), 'Tree check after joining.') if DEBUG;


for (1..$n_mcmc_steps) {

  $mc_tree->mcmc_step_split();
  print $mc_tree->n_leaves(), "  ", $mc_tree->newick(), "\n";

  $mc_tree->mcmc_step_join();
  print $mc_tree->n_leaves(), "  ", $mc_tree->newick(), "\n";

}



