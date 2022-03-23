#!/usr/bin/perl
# Process a Brownfield Sites (GeoJSON) working out the MSOA for each site
# Version 1.1

use JSON::XS;
use Data::Dumper;
use Math::Trig;

use constant PI => 4 * atan2(1, 1);
use constant X         => 0;
use constant Y         => 1;
use constant TWOPI    => 2*PI;


$brownfieldfile = "data/brownfield-sites.geojson";
$msoafile = "data/msoas-fixed.geojson";
$ofile = "data/brownfield-areas.csv";

if(!-e $brownfieldfile){
	print "No GeoJSON with brownfield sites. You may wish to run getData.pl first.\n";
	exit;
}

# Load the MSOA features (this will calculate bounding boxes for them too)
# We will use @msoafeatures in getMSOA() later
@msoafeatures = loadFeatures($msoafile);

# Load in the brownfield land features
@features = loadFeatures($brownfieldfile);

# Find out how many features there are
$n = @features;
print "Loaded $n brownfield land features.\n";

# Loop over the features
for($i = 0; $i < $n; $i++){
	if($features[$i]{'geometry'}{'type'} ne "Point"){
		print "ERROR for features $i\n";
	}else{

		# Get the area for this feature
		$area = $features[$i]{'properties'}{'json'}{'hectares'};

		# Get the name of this feature
		$name = $features[$i]{'properties'}{'json'}{'site-address'};

		# Get the latitude and longitude of the feature
		$lon = $features[$i]{'geometry'}{'coordinates'}[0];
		$lat = $features[$i]{'geometry'}{'coordinates'}[1];
		
		# Work out the MSOA this point is in
		# e.g. getMSOA(51.46586,-3.16868);
		$msoa = getMSOA($lat,$lon);

		# If we have an MSOA we add the area to the total for it
		if($msoa){
			# If we haven't already noted this MSOA we create a 0 value for it
			if(!$msoas{$msoa}){ $msoas{$msoa} = 0; }
			$msoas{$msoa} += $area;
		}else{
			print "No MSOA found for ($lat,$lon) - feature $i / $n\n";
		}
	}
	
}

# Save MSOA-binned output to a CSV file
open(FILE,">",$ofile);
print FILE "msoa,brownfield area\n";
# Print the sorted MSOA values
foreach $msoa (sort(keys(%msoas))){
	print FILE "$msoa,$msoas{$msoa}\n";
}
close(FILE);




##########################
# SUBROUTINES

sub loadFeatures {
	my $file = $_[0];
	my (@lines,$str,$json,@features,$coder);
	
	
	# Define a JSON loader
	$coder = JSON::XS->new->utf8->canonical(1);

	print "Reading $file\n";
	open(FILE,$file);
	@lines = <FILE>;
	close(FILE);
	$str = join("",@lines);

	# Decode the string
	$json = $coder->decode($str);

	@features = @{$json->{'features'}};

	# Work out the bounding box for this feature
	my ($f,@gs,$ok,$minlat,$maxlat,$minlon,$maxlon,$n);
	for($f = 0; $f < @features; $f++){
		@gs = "";
		$ok = 0;
		#print "Feature $f:\n";
		$minlat = 90;
		$maxlat = -90;
		$minlon = 180;
		$maxlon = -180;
		if($features[$f]->{'geometry'}->{'type'} eq "Polygon"){
			($minlat,$maxlat,$minlon,$maxlon) = getBBox($minlat,$maxlat,$minlon,$maxlon,@{$features[$f]->{'geometry'}->{'coordinates'}});
			# Set the bounding box
			$features[$f]->{'geometry'}{'bbox'} = {'lat'=>{'min'=>$minlat,'max'=>$maxlat},'lon'=>{'min'=>$minlon,'max'=>$maxlon}};
		}elsif($features[$f]->{'geometry'}->{'type'} eq "MultiPolygon"){
			$n = @{$features[$f]->{'geometry'}->{'coordinates'}};
			for($p = 0; $p < $n; $p++){
				($minlat,$maxlat,$minlon,$maxlon) = getBBox($minlat,$maxlat,$minlon,$maxlon,@{$features[$f]->{'geometry'}->{'coordinates'}[$p]});
			}
			# Set the bounding box
			$features[$f]->{'geometry'}{'bbox'} = {'lat'=>{'min'=>$minlat,'max'=>$maxlat},'lon'=>{'min'=>$minlon,'max'=>$maxlon}};
		}else{
			#print "ERROR: Unknown geometry type $features[$f]->{'geometry'}->{'type'}\n";
		}
	}

	# Get the features
	return @features;
}

sub getBBox {
	my @gs = @_;
	my ($minlat,$maxlat,$minlon,$maxlon,$n,$i);
	$minlat = shift(@gs);
	$maxlat = shift(@gs);
	$minlon = shift(@gs);
	$maxlon = shift(@gs);
	$n = @{$gs[0]};

	for($i = 0; $i < $n; $i++){
		if($gs[0][$i][0] < $minlon){ $minlon = $gs[0][$i][0]; }
		if($gs[0][$i][0] > $maxlon){ $maxlon = $gs[0][$i][0]; }
		if($gs[0][$i][1] < $minlat){ $minlat = $gs[0][$i][1]; }
		if($gs[0][$i][1] > $maxlat){ $maxlat = $gs[0][$i][1]; }
	}
	return ($minlat,$maxlat,$minlon,$maxlon);
}

sub getMSOA {
	my $lat = $_[0];
	my $lon = $_[1];
	my $msoa = "";
	my ($f,$n,$ok,@gs);
	
	for($f = 0; $f < @msoafeatures; $f++){
		@gs = "";
		$ok = 0;
		# If we are in the bounding box
		if($lat >= $msoafeatures[$f]->{'geometry'}{'bbox'}{'lat'}{'min'} && $lat <= $msoafeatures[$f]->{'geometry'}{'bbox'}{'lat'}{'max'} && $lon >= $msoafeatures[$f]->{'geometry'}{'bbox'}{'lon'}{'min'} && $lon <= $msoafeatures[$f]->{'geometry'}{'bbox'}{'lon'}{'max'}){
			if($msoafeatures[$f]->{'geometry'}->{'type'} eq "Polygon"){
				$ok = withinPolygon($lat,$lon,@{$msoafeatures[$f]->{'geometry'}->{'coordinates'}});
			}else{
				$n = @{$msoafeatures[$f]->{'geometry'}->{'coordinates'}};
				$ok = withinMultiPolygon($lat,$lon,@{$msoafeatures[$f]->{'geometry'}->{'coordinates'}});
			}
			if($ok){
				return $msoafeatures[$f]->{'properties'}->{'msoa11cd'};
			}
		}
	}
	return $msoa;
}

sub withinMultiPolygon {
	my @gs = @_;
	my ($lat,$lon,$p,$n,$ok);
	$lat = shift(@gs);
	$lon = shift(@gs);
	$n = @gs;

	for($p = 0; $p < $n; $p++){
		if(withinPolygon($lat,$lon,@{$gs[$p]})){
			return 1;
		}
	}
	return 0;
}

sub withinPolygon {
	my @gs = @_;
	my ($lat,$lon,$p,$n,$ok,$hole);
	$lat = shift(@gs);
	$lon = shift(@gs);
	$ok = 0;
	$n = @gs;

	$ok = (PtInPoly( \@{$gs[0]}, [$lon,$lat]) ? 1 : 0);

	if($ok){
		if($n > 1){
			#print "Check if in hole\n";
			for($p = 1; $p < $n; $p++){
				$hole = (PtInPoly( \@{$gs[$p]}, [$lon,$lat]) ? 1 : 0);
				if($hole){
					print "Found in hole in Polygon $p\n";
					return 0;
				}
			}
		}
		return 1;
	}

	return 0;
}

sub mapAdjPairs (&@) {
    my $code = shift;
    map { local ($a, $b) = (shift, $_[0]); $code->() } 0 .. @_-2;
}

sub Angle{
    my ($x1, $y1, $x2, $y2) = @_;
    my $dtheta = atan2($y1, $x1) - atan2($y2, $x2);
    $dtheta -= TWOPI while $dtheta >   PI;
    $dtheta += TWOPI while $dtheta < - PI;
    return $dtheta;
}
sub PtInPoly{
    my ($poly, $pt) = @_;
    my $angle=0;

    mapAdjPairs{
        $angle += Angle(
            $a->[X] - $pt->[X],
            $a->[Y] - $pt->[Y],
            $b->[X] - $pt->[X],
            $b->[Y] - $pt->[Y]
        )
    } @$poly, $poly->[0];

    return !(abs($angle) < PI);
}