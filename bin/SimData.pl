#!/usr/bin/perl -w
use strict;

my $N = shift;
my $p = shift;
my $hiP = shift || 0.9;
for my $i (1..$N) {
  my $answer_string = '';
  for my $j (1..$p) {
    my $prob_1 = $hiP - ($hiP-0.5)*$j/$p;
    my $answer = (rand() < $prob_1)? 1 : 0;
    $answer_string .= "$answer";
  }
  print "$answer_string \n";
}
