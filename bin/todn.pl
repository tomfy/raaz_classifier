#!/usr/bin/perl -w
use strict;

my $max_d = shift || 8;

my %depth_ntrees = ( 0 => 1, 1 => 1 );

for my $d (0..$max_d){
	print "max depth:  $d, number of trees: ", todn($d, \%depth_ntrees), "\n";
}


sub todn{
my $d = shift; # max depth
my $depth_ntrees = shift;
if(defined $depth_ntrees->{$d}){
return $depth_ntrees->{$d};
}else{
	my $todn_dm1 = todn($d - 1, $depth_ntrees);
	my $sum = 0;
	for(0..$d-2){
	$sum += todn($_, $depth_ntrees);
}
	my $result = $todn_dm1*($todn_dm1 + 2*$sum);
	$depth_ntrees->{$d} = $result;
	return $result;
}
}
	
