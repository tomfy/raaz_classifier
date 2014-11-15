#!/usr/bin/perl -w
use strict;
use Data;
use Tree;
use Node;


my $input_data_filename = shift or die "No data file given.\n";

my $data_obj = Data->new( { data_source_filename => $input_data_filename } );

print $data_obj->data_as_string(), "\n";

my $tree_obj = Tree->new( { data => $data_obj } );

print $tree_obj->info_string(), "\n";

$tree_obj->root()->split_node(1e-10);

print $tree_obj->info_string(), "\n";

my @leaf_ukeys = keys %{$tree_obj->leaf_unikeys()};
print STDERR join(", ", @leaf_ukeys), "\n";
for my $a_leaf_unikey (@leaf_ukeys){
  my $leaf_node = $tree_obj->unikey_node()->{$a_leaf_unikey};
  $leaf_node->split_node(1e-10);
}
print $tree_obj->info_string(), "\n";

print $tree_obj->newick(), "\n";
die "check failed after splitting.\n" if(! $tree_obj->check());


for my $a_leaf_unikey (@leaf_ukeys) {
  my $leaf_node = $tree_obj->unikey_node()->{$a_leaf_unikey};
  $leaf_node->join_nodes(1e10);
}
print $tree_obj->info_string(), "\n";

print $tree_obj->newick(), "\n";
die "check failed after joining.\n" if(! $tree_obj->check());

for (1..100) {
  $tree_obj->mcmc_step_split();
  # print $tree_obj->newick(), "\n";
  print "n_leaves: ", $tree_obj->n_leaves(), "\n";
  $tree_obj->mcmc_step_join();
  # print $tree_obj->newick(), "\n";
  print "n_leaves: ", $tree_obj->n_leaves(), "\n";
}



