#!/usr/bin/perl

use strict;

# top2psf - a tool designed to take a GROMACS topology and construct a .psf file for use with VMD.
# The purpose of this tool is to make use of bond information in, e.g. coarse grain structures.
#
# The program takes a GROMACS topology file as its input. 
#
# PLEASE NOTE: This program is written very specifically for MARTINI topologies (i.e., the
# pattern matching expects the layout to be based on the order of the topology and the 
# comments therein.
#
# Version 1.0 (10/19/2009)
#
# Written by Justin Lemkul (jalemkul[at]vt[dot]edu)
# Distributed under the GNU General Public License
#

unless(@ARGV) {
	print "Usage: $0 -i (topology filename) -o (output filename)\n";
	exit;
}

# define input hash
my %options = @ARGV;

# open input
my $input;

if (defined($options{"-i"})) {
	$input = $options{"-i"};
} else {
	print "No input defined.\n";
	exit;
}

# store the input topology in an array
open(IN, $input) or die "Cannot open $input: $!\n";
my @topology_in = <IN>;
close(IN);

# open output
my $output;

if (defined($options{"-o"})) {
	$output = $options{"-o"};
} else {
	print "No output defined.\n";
	exit;
}

# Determine how many atoms and residues are in the protein
my $last_res;
my $last_atom;

for (my $i=0; $i<scalar(@topology_in); $i++) {
	if ($topology_in[$i+2] =~ /\[ bonds \]/ || $topology_in[$i+2] =~ /\[bonds\]/) {
		my @line = split(" ", $topology_in[$i]);
		$last_res = $line[2];
		$last_atom = $line[0];
	}
}

# Write the header of the .psf file
open(OUT, ">>$output") or die "Cannot open $output: $!\n";

print OUT "PSF\n";
print OUT "\n";
printf OUT "%8d !NTITLE\n", 10;
printf OUT "%8s topology generated by top2psf\n", "REMARKS";
printf OUT "%8s topology $input\n", "REMARKS";
printf OUT "%8s topology from GROMACS\n", "REMARKS";
printf OUT "%8s segment P1 { first NTER\; last CTER\; auto angles dihedrals }\n", "REMARKS";
printf OUT "%8s patch NTER P1:1\n", "REMARKS";
printf OUT "%8s patch CTER P1:%d\n", "REMARKS", $last_res;
printf OUT "%8s\n", "REMARKS";
printf OUT "%8s\n", "REMARKS";
printf OUT "%8s\n", "REMARKS";
printf OUT "%8s\n", "REMARKS";
printf OUT "\n";

# Print out the header of the atoms section
printf OUT "%8d !NATOM\n", $last_atom;

# Idea is to run thru the array (topology file), matching the directives (atoms, bonds, etc)
for (my $i=0; $i<scalar(@topology_in); $i++) {
	if ($topology_in[$i] =~ /\[ atoms \]/ || $topology_in[$i] =~ /\[atoms\]/) {

		open(ATOM_TMP, ">>atoms") or die "Cannot open atoms for writing: $!\n";		
		for (my $j=$i; $j<scalar(@topology_in); $j++) {
			if ($topology_in[$j+1] =~ /\[ bonds \]/ || $topology_in[$j+1] =~ /\[bonds\]/) {
				last;	
			} else {
				printf ATOM_TMP $topology_in[$j];
			}
		}
			
	} elsif ($topology_in[$i] =~ /\[ bonds \]/ || $topology_in[$i] =~ /\[bonds\]/) {

		# In MARTINI topology, both [ bonds ] and [ constraints ] represent bonds
		open(BOND_TMP, ">>bonds") or die "Cannot open bonds for writing: $!\n";
                for (my $j=$i; $j<scalar(@topology_in); $j++) {
                        if ($topology_in[$j+1] =~ /\[ angles \]/ || $topology_in[$j+1] =~ /\[angles\]/) {
                                last;
                        } else {
                                printf BOND_TMP $topology_in[$j];
                        }
                }

	} elsif ($topology_in[$i] =~ /\[ angles \]/ || $topology_in[$i] =~ /\[angles\]/) {

                open(ANGLE_TMP, ">>angles") or die "Cannot open angles for writing: $!\n";
                for (my $j=$i; $j<scalar(@topology_in); $j++) {
                        if ($topology_in[$j+1] =~ /\[ dihedrals \]/ || $topology_in[$j+1] =~ /\[dihedrals\]/) {
                                last;
                        } else {
                                printf ANGLE_TMP $topology_in[$j];
                        }
                }

	} elsif ($topology_in[$i] =~ /\[ dihedrals \]/ || $topology_in[$i] =~ /\[dihedrals\]/) {
	
		open(DIH_TMP, ">>dihedrals") or die "Cannot open dihedrals for writing: $!\n";
		# dihedrals are the last entry in a MARTINI topology
		# impropers first, then propers - will need to split this later
		for (my $j=$i; $j<scalar(@topology_in); $j++) {
			printf DIH_TMP $topology_in[$j];
		}
	}
}

close(ATOM_TMP);
close(BOND_TMP);
close(ANGLE_TMP);
close(DIH_TMP);

# Write atoms section to .psf file
open(NEW_ATOM_IN, "<atoms") or die "Cannot open atoms for reading: $!\n";
my @atoms = <NEW_ATOM_IN>;
close(NEW_ATOM_IN);

shift(@atoms);	# get rid of [ atoms ] directive header

my $atom_num;
my $res_num;
my $res_name;
my $atom_name;
my $atom_type;
my $charge;
my $mass;

foreach $_ (@atoms) {
	my @info = split(" ", $_);

	$atom_num = $info[0];
	$atom_type = $info[1];
	$res_num = $info[2];
	$res_name = $info[3];
	$atom_name = $info[4];
	$charge = $info[6];
	$mass = $info[7];
	
	printf OUT "%8d P1 %4d%7s  %-4s %-3s%12.6f%14.4f%12d\n", $atom_num, $res_num, $res_name, $atom_name, $atom_type, $charge, $mass, 0;
}

# space between atoms and bonds section
print OUT "\n";

# Write bonds section to .psf file
open(NEW_BOND_IN, "<bonds") or die "Cannot open bonds for reading: $!\n";
my @bonds = <NEW_BOND_IN>;
close(NEW_BOND_IN);

shift(@bonds);	# get rid of [ bonds ] directive header
shift(@bonds); 	# get rid of comment line

# clean up comments, newlines, and [ constraints ] directive within [ bonds ] section
for (my $i=0; $i<scalar(@bonds); $i++) {
	if ($bonds[$i] =~ /^\;b/ || $bonds[$i] =~ /^\;l/  || $bonds[$i] =~ /^\;s/ || $bonds[$i] =~ /^\n$/ || ($bonds[$i] =~ /\[ constraints \]/ || $bonds[$i] =~ /\[constraints\]/)) {
		splice(@bonds, $i, 1);
		$i--;
	}
}

my $number_of_bonds = scalar(@bonds);	# get bond count

printf OUT "%8d !NBOND: bonds\n", $number_of_bonds;

# assemble the bond lines
open(NEW_BOND_OUT, ">>bonds_fix") or die "Cannot open bonds_fix for writing: $!\n";

chomp(@bonds);	# remove newlines

# clean up array, remove function types
my @bonds_clean;

foreach $_ (@bonds) {
	chop($_);
	push(@bonds_clean, $_);
}

# The checks in this section may not be entirely necessary, since the @bonds array
# was cleaned previously.  In any case, it works, so I won't mess with it.
for (my $i=0; $i<scalar(@bonds_clean); $i+=4) {

	if (defined($bonds_clean[$i+3])) {
		my @line1 = split(" ", $bonds_clean[$i]);
		my @line2 = split(" ", $bonds_clean[$i+1]);
		my @line3 = split(" ", $bonds_clean[$i+2]);
		my @line4 = split(" ", $bonds_clean[$i+3]);

		my $i1 = $line1[0];
		my $j1 = $line1[1];

		my $i2 = $line2[0];
		my $j2 = $line2[1];

		my $i3 = $line3[0];
		my $j3 = $line3[1];

		my $i4 = $line4[0];
		my $j4 = $line4[1];

		my $line_concat = "$i1 $j1 $i2 $j2 $i3 $j3 $i4 $j4\n"; 
		my @line = split(" ", $line_concat);
		printf NEW_BOND_OUT "%8d%8d%8d%8d%8d%8d%8d%8d\n", $i1, $j1, $i2, $j2, $i3, $j3, $i4, $j4;
	} elsif ((!defined($bonds_clean[$i+3])) && (defined($bonds_clean[$i+2]))) {
		my @line1 = split(" ", $bonds_clean[$i]);
                my @line2 = split(" ", $bonds_clean[$i+1]);
                my @line3 = split(" ", $bonds_clean[$i+2]);

                my $i1 = $line1[0];
                my $j1 = $line1[1];

                my $i2 = $line2[0];
                my $j2 = $line2[1];

                my $i3 = $line3[0];
                my $j3 = $line3[1];

		my $line_concat = "$i1 $j1 $i2 $j2 $i3 $j3\n";
                my @line = split(" ", $line_concat);
                printf NEW_BOND_OUT "%8d%8d%8d%8d%8d%8d\n", $i1, $j1, $i2, $j2, $i3, $j3;
	} elsif ((!defined($bonds_clean[$i+2])) && (defined($bonds_clean[$i+1]))) {
		my @line1 = split(" ", $bonds_clean[$i]);
                my @line2 = split(" ", $bonds_clean[$i+1]);

                my $i1 = $line1[0];
                my $j1 = $line1[1];

                my $i2 = $line2[0];
                my $j2 = $line2[1];

                my $line_concat = "$i1 $j1 $i2 $j2\n";
                my @line = split(" ", $line_concat);
                printf NEW_BOND_OUT "%8d%8d%8d%8d\n", $i1, $j1, $i2, $j2;
	} elsif ((!defined($bonds_clean[$i+1])) && (defined($bonds_clean[$i]))) {
                my @line1 = split(" ", $bonds_clean[$i]);

                my $i1 = $line1[0];
                my $j1 = $line1[1];

                my $line_concat = "$i1 $j1\n";
                my @line = split(" ", $line_concat);
                printf NEW_BOND_OUT "%8d%8d\n", $i1, $j1;
	}

}

close(NEW_BOND_OUT);

open(BONDS_FIX, "<bonds_fix") or die "Cannot open bonds_fix for reading: $!\n";
my @bonds_fix = <BONDS_FIX>;
close(BONDS_FIX);

foreach $_ (@bonds_fix) {
	print OUT $_;
}

# Add space between bonds and angles
print OUT "\n";

open(NEW_ANGLE_IN, "<angles") or die "Cannot open angles for reading: $!\n";
my @angles = <NEW_ANGLE_IN>;
close(NEW_ANGLE_IN);

shift(@angles);	# remove [ angles ] directive
shift(@angles);	# remove column headers

my $number_of_angles = scalar(@angles);

printf OUT "%8d !NTHETA: angles\n", $number_of_angles;

# assemble the angle lines
open(NEW_ANGLE_OUT, ">>angles_fix") or die "Cannot open angles_fix for writing: $!\n";

chomp(@angles);  # remove newlines

# clean up array, remove function types
my @angles_clean;

foreach $_ (@angles) {
        chop($_);
        push(@angles_clean, $_);
}

for (my $i=0; $i<scalar(@angles_clean); $i+=3) {

        my @line1 = split(" ", $angles_clean[$i]);
        my @line2 = split(" ", $angles_clean[$i+1]);
        my @line3 = split(" ", $angles_clean[$i+2]);

        my $i1 = $line1[0];
        my $j1 = $line1[1];
	my $k1 = $line1[2];

        my $i2 = $line2[0];
        my $j2 = $line2[1];
	my $k2 = $line2[2];

        my $i3 = $line3[0];
        my $j3 = $line3[1];
	my $k3 = $line3[2];

        my $line_concat = "$i1 $j1 $k1 $i2 $j2 $k2 $i3 $j3 $k3\n";
        my @line = split(" ", $line_concat);
        printf NEW_ANGLE_OUT "%8d%8d%8d%8d%8d%8d%8d%8d%8d\n", $i1, $j1, $k1, $i2, $j2, $k2, $i3, $j3, $k3;
}

close(NEW_ANGLE_OUT);

open(ANGLES_FIX, "<angles_fix") or die "Cannot open angles_fix for reading: $!\n";
my @angles_fix = <ANGLES_FIX>;
close(ANGLES_FIX);

foreach $_ (@angles_fix) {
        print OUT $_;
}

# print space between angle and dihedral section
print OUT "\n";

open(NEW_DIH_IN, "<dihedrals") or die "Cannot open dihedrals for reading: $!\n";
my @dihedrals = <NEW_DIH_IN>;
close(NEW_DIH_IN);

shift(@dihedrals); # remove [ dihedrals ] directive
shift(@dihedrals); # remove comment lines

# This part is very MARTINI-specific, since the [ dihedrals ] directive is formatted 
# differently from the standard GROMACS setup. Normally, there are two [ dihedrals ] 
# directives, but in MARTINI there is only one, with comment lines separating the 
# impropers from the propers.

my $improper_count = 0;
open(IMPROPERS, ">>impropers") or die "Cannot open impropers for writing: $!\n";
for (my $j=0; $j<scalar(@dihedrals); $j++) {
	if ($dihedrals[$j] =~ /;proper/) {
		last;
	} else {
		printf IMPROPERS $dihedrals[$j];
		$improper_count++;
	}
}
close(IMPROPERS);

# shorten @dihedrals to account for removed lines?
splice(@dihedrals, 0, $improper_count);

shift(@dihedrals);
shift(@dihedrals);

open(PROPERS, ">>propers") or die "Cannot open propers for writing: $!\n";
for (my $k=0; $k<scalar(@dihedrals); $k++) {
	print PROPERS $dihedrals[$k];
}

my $number_of_dihedrals = scalar(@dihedrals);

printf OUT "%8d !NPHI: dihedrals\n", $number_of_dihedrals;

# assemble the angle lines
open(NEW_PROPER_OUT, ">>propers_fix") or die "Cannot open propers_fix for writing: $!\n";

chomp(@dihedrals);  # remove newlines

# clean up array, remove function types
my @dihedrals_clean;

foreach $_ (@dihedrals) {
        chop($_);
        push(@dihedrals_clean, $_);
}

for (my $i=0; $i<scalar(@dihedrals_clean); $i+=3) {

        my @line1 = split(" ", $dihedrals_clean[$i]);
        my @line2 = split(" ", $dihedrals_clean[$i+1]);

        my $i1 = $line1[0];
        my $j1 = $line1[1];
        my $k1 = $line1[2];
	my $l1 = $line1[3];

        my $i2 = $line2[0];
        my $j2 = $line2[1];
        my $k2 = $line2[2];
	my $l2 = $line2[3];

        my $line_concat = "$i1 $j1 $k1 $l1 $i2 $j2 $k2 $l2\n";
        my @line = split(" ", $line_concat);
        printf NEW_PROPER_OUT "%8d%8d%8d%8d%8d%8d%8d%8d\n", $i1, $j1, $k1, $l1, $i2, $j2, $k2, $l2;
}

close(NEW_PROPER_OUT);

open(PROPERS_FIX, "<propers_fix") or die "Cannot open propers_fix for reading: $!\n";
my @propers_fix = <PROPERS_FIX>;
close(PROPERS_FIX);

foreach $_ (@propers_fix) {
        print OUT $_;
}

# Print space between dihedrals and impropers section
print OUT "\n";

open(NEW_IMPROPER, "<impropers") or die "Cannot open impropers for reading: $!\n";
my @impropers = <NEW_IMPROPER>;
close(NEW_IMPROPER);

my $number_of_impropers = scalar(@impropers);

printf OUT "%8d !NIMPHI: impropers\n", $number_of_impropers;

# assemble the angle lines
open(NEW_IMPROPER_OUT, ">>impropers_fix") or die "Cannot open impropers_fix for writing: $!\n";

chomp(@impropers);  # remove newlines

# clean up array, remove function types
my @impropers_clean;

foreach $_ (@impropers) {
        chop($_);
        push(@impropers_clean, $_);
}

for (my $i=0; $i<scalar(@impropers_clean); $i+=3) {

        my @line1 = split(" ", $impropers_clean[$i]);
        my @line2 = split(" ", $impropers_clean[$i+1]);

        my $i1 = $line1[0];
        my $j1 = $line1[1];
        my $k1 = $line1[2];
        my $l1 = $line1[3];

        my $i2 = $line2[0];
        my $j2 = $line2[1];
        my $k2 = $line2[2];
        my $l2 = $line2[3];

        my $line_concat = "$i1 $j1 $k1 $l1 $i2 $j2 $k2 $l2\n";
        my @line = split(" ", $line_concat);
        printf NEW_IMPROPER_OUT "%8d%8d%8d%8d%8d%8d%8d%8d\n", $i1, $j1, $k1, $l1, $i2, $j2, $k2, $l2;
}

close(NEW_IMPROPER_OUT);

open(IMPROPERS_FIX, "<impropers_fix") or die "Cannot open impropers_fix for reading: $!\n";
my @impropers_fix = <IMPROPERS_FIX>;
close(IMPROPERS_FIX);

foreach $_ (@impropers_fix) {
        print OUT $_;
}

# Now, some other sections that don't actually depend on the topology
print OUT "\n";
printf OUT "%8d !NDON: donors\n", 0;
print OUT "\n\n";
printf OUT "%8d !NACC: acceptors\n", 0;
print OUT "\n\n";
printf OUT "%8d !NNB\n", 0;
print OUT "\n\n";
printf OUT "%8d%8d !NGRP\n", 1, 0;
printf OUT "%8d%8d%8d\n", 0, 0, 0;

close(OUT);

# Clean up
unlink "atoms";
unlink "bonds";
unlink "bonds_fix";
unlink "angles";
unlink "angles_fix";
unlink "dihedrals";
unlink "impropers";
unlink "impropers_fix";
unlink "propers";
unlink "propers_fix";