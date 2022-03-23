#!/usr/bin/perl
# Code to download the Brownfield sites data from Digital Land

use JSON::XS;
use Data::Dumper;

# Create a JSON encoder/decoder
$coder = JSON::XS->new->utf8->canonical(1)->pretty;

# Download the data. It will go through all the pages until it gets everything.
@features = downloadFromDigitalLand("https://www.digital-land.info/entity.geojson?dataset=brownfield-land&limit=500");

# How many features do we have?
$n = @features;

# Build some JSON-style output
$json = {'features'=>\@features,'type'=>'FeatureCollection'};

# Convert the object into a JSON string
$jsonstr = $coder->encode($json);

# Tidy the string to have one feature per line and trim whitespace
$jsonstr =~ s/ {3}/\t/g;
$jsonstr =~ s/\n\t\t\t+//g;
$jsonstr =~ s/\n\t\t\}/\}/g;
$jsonstr =~ s/ : /:/g;
$jsonstr =~ s/\t\t"",?\n//g;	# Remove missing features
$jsonstr =~ s/\},\n\t\]/\}\n\t\]/g;	# Tidy up end

# Sae the result
open(FILE,">","brownfield-sites.geojson");
print FILE $jsonstr;
close(FILE);

print "$n features\n";



########################
# SUBROUTINES

sub downloadFromDigitalLand {
	my $url = shift(@_);
	my @features = @_;
	my ($str,$json);
	
	print "Getting $url...\n";
	$str = `wget -q --no-check-certificate -O- "$url"`;
	$json = $coder->decode($str);
	push(@features,@{$json->{'features'}});
	
	if($json->{'links'}{'next'}){
		#print "Need to download $json->{'links'}{'next'}\n";
		push(@features,downloadFromDigitalLand($json->{'links'}{'next'}));
	}

	return @features;
}
