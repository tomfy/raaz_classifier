#!/usr/bin/perl -w
use strict;
use lib '/home/tomfy/Raaz/lib';
use Data;
use Tree;
use MCTree;
use Node;

my $rand_seed = srand(12345);
print STDERR "# $rand_seed \n";

my $input_data_filename = shift or die "No data file given.\n";
my $n_mcmc_steps = shift || 200;
my $repeatable = shift || 0; # 
my $data_obj = Data->new( { data_source_filename => $input_data_filename } );

# print "# ", $data_obj->data_as_string(), "\n";

my $sum_tree = Tree->new();
#exit;
my $tree_obj =MCTree->new( { data => $data_obj, N => $data_obj->N(), repeatable => $repeatable, sum_tree => $sum_tree }); #$repeatable } );
print "# ", $tree_obj->info_string(), "\n";

#exit;

$tree_obj->root()->split_node_mcmc(1e-10);

print "# ", $tree_obj->info_string(), "\n";

my @leaf_ukeys = keys %{$tree_obj->leaf_unikeys()};
print STDERR "# ", join(", ", @leaf_ukeys), "\n";
for my $a_leaf_unikey (@leaf_ukeys){
  my $leaf_node = $tree_obj->unikey_node()->{$a_leaf_unikey};
  $leaf_node->split_node_mcmc(1e-10);
}
print "# ", $tree_obj->info_string(), "\n";

print "# ", $tree_obj->newick(), "\n";
die "check failed after splitting.\n" if(! $tree_obj->check());


for my $a_leaf_unikey (@leaf_ukeys) {
  my $leaf_node = $tree_obj->unikey_node()->{$a_leaf_unikey};
  $leaf_node->join_nodes_mcmc(1e10);
}
print "# ", $tree_obj->info_string(), "\n";

print "# ", $tree_obj->newick(), "\n";
die "check failed after joining.\n" if(! $tree_obj->check());

for (1..$n_mcmc_steps) {
  # print STDERR "mcmc split: $_\n";
  $tree_obj->mcmc_step_split();
  print $tree_obj->n_leaves(), "  ", $tree_obj->newick(), "\n";
 # print "n_leaves: ", $tree_obj->n_leaves(), "\n";
# print STDERR "mcmc join: $_\n";
  $tree_obj->mcmc_step_join();
  print $tree_obj->n_leaves(), "  ", $tree_obj->newick(), "\n";
  # print $tree_obj->newick(), "\n";
 # print "n_leaves: ", $tree_obj->n_leaves(), "\n";
}



