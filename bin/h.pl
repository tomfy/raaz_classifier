#!/usr/bin/perl -w
use strict;
use lib '/home/tomfy/Raaz/lib';
use Data;
use Tree;
use MCTree;
use Node;

my $rand_seed = srand(12345);
print STDERR "# RNG seed: $rand_seed \n";

my $input_data_filename = shift or die "No data file given.\n";
my $n_mcmc_steps = shift || 200;
my $repeatable = shift || 0; # 
my $data_obj = Data->new( { data_source_filename => $input_data_filename } );

# print "# ", $data_obj->data_as_string(), "\n";

my $sum_tree = Tree->new();
#exit;
my $mc_tree =MCTree->new( { data => $data_obj, N => $data_obj->N(), repeatable => $repeatable, sum_tree => $sum_tree }); #$repeatable } );
print "# init mc_tree info: ", $mc_tree->info_string(), "\n";

#exit;

#$mc_tree->root()->split_node_mcmc(1e-10);
 my ($accept, $pp_ratio, $l_q_indices, $r_q_indices, $l_p_indices, $r_p_indices);
 #  $mc_tree->root()->split_node_mcmc(1e-10);
#  if (0) {
# ($accept, $l_q_indices, $r_q_indices, $l_p_indices, $r_p_indices) =  $mc_tree->root()->split_node_mcmc(1e-10);
# if($accept){ $mc_tree->root()->split_node($l_q_indices, $r_q_indices, $l_p_indices, $r_p_indices); }
#  }else{
rand();
 ($pp_ratio, $l_q_indices, $r_q_indices, $l_p_indices, $r_p_indices) = $mc_tree->root()->split_node_pp_ratio();
    $mc_tree->root()->split_node($l_q_indices, $r_q_indices, $l_p_indices, $r_p_indices);
 # }
print "# ", $mc_tree->info_string(), "\n";

my @leaf_ukeys = keys %{$mc_tree->leaf_unikeys()};
print STDERR "# ", join(", ", @leaf_ukeys), "\n";
#my $accept;
for my $a_leaf_unikey (@leaf_ukeys) {
  my $leaf_node = $mc_tree->unikey_node()->{$a_leaf_unikey};
  # if (0) {
  #   ($accept, $l_q_indices, $r_q_indices, $l_p_indices, $r_p_indices) = 
  #     $leaf_node->split_node_mcmc(1e-10);
  #   if ($accept) {
  #     $leaf_node->split_node($l_q_indices, $r_q_indices, $l_p_indices, $r_p_indices);
  #   }
  # } else {
rand();
 ($pp_ratio, $l_q_indices, $r_q_indices, $l_p_indices, $r_p_indices) = $leaf_node->split_node_pp_ratio();
    $leaf_node->split_node($l_q_indices, $r_q_indices, $l_p_indices, $r_p_indices);
  #}
}
print "# ", $mc_tree->info_string(), "\n";

print "# ", $mc_tree->newick(), "\n";
die "check failed after splitting.\n" if(! $mc_tree->check());

print "# leaf addresses: ", join(", ", @leaf_ukeys), "\n";
for my $a_leaf_unikey (@leaf_ukeys) {
  my $leaf_node = $mc_tree->unikey_node()->{$a_leaf_unikey};
rand();
    $leaf_node->join_nodes();
}
print "# ", $mc_tree->info_string(), "\n";
# exit;
print "# ", $mc_tree->newick(), "\n";
die "check failed after joining.\n" if(! $mc_tree->check());

for (1..$n_mcmc_steps) {
  # print STDERR "mcmc split: $_\n";
  $mc_tree->mcmc_step_split();
  print $mc_tree->n_leaves(), "  ", $mc_tree->newick(), "\n";
 # print "n_leaves: ", $mc_tree->n_leaves(), "\n";
# print STDERR "mcmc join: $_\n";
  $mc_tree->mcmc_step_join();
  print $mc_tree->n_leaves(), "  ", $mc_tree->newick(), "\n";
  # print $mc_tree->newick(), "\n";
 # print "n_leaves: ", $mc_tree->n_leaves(), "\n";
}



