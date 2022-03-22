#!/usr/bin/perl
# Process a Brownfield Sites CSV file working out the MSOA for each site
# Version 1.0

use JSON::XS;
use Data::Dumper;
use Text::CSV;
use Math::Trig;
use Geo::Coordinates::OSGB qw(ll_to_grid grid_to_ll);

use constant PI => 4 * atan2(1, 1);
use constant X         => 0;
use constant Y         => 1;
use constant TWOPI    => 2*PI;


$csvfile = $ARGV[0]||"../brownfield-sites.csv";
$geojson = "msoas-fixed.geojson";
$ofile = "brownfield-sites.geojson";
$msoafile = "brownfield-areas.csv";


@features = loadFeatures($geojson);

#print getMSOA(53.7940,-1.5813)."\n";
#print getMSOA(53.8350,-1.6437)."\n";
#print getMSOA(51.46586,-3.16868)."\n";
#print getMSOA(55,-3.16868)."\n";

%header;
%msoas;
my $csv = Text::CSV->new ({ binary => 1 });
open my $fh,'<:encoding(utf8)',$csvfile;
while (my $row = $csv->getline($fh)){
	my @cols = @$row;
	if($i == 0){
		@head = @cols;
		for($c = 0; $c < @head; $c++){
			$header{$head[$c]} = $c;
		}
	}else{
		$lat = $cols[$header{'GeoY'}];
		$lon = $cols[$header{'GeoX'}];
		
		
		if($cols[$header{'CoordinateReferenceSystem'}] eq "OSGB36"){
			($lat,$lon) = grid_to_ll($lat,$lon);
		}
		$area = $cols[$header{'Hectares'}];
		$name = $cols[$header{'SiteNameAddress'}];
		$name =~ s/(^\"|\"$)//g;
		$name =~ s/[\r\n]+/, /g;
		$msoa = getMSOA($lat,$lon);
		if($msoa){
			if(!$msoas{$msoa}){ $msoas{$msoa} = 0; }
			$msoas{$msoa} += $area;
		}
		$out .= ($out ? ",\n":"")."\t\t{ \"type\":\"Feature\",\"properties\":{\"name\":\"$name\",\"msoa11cd\":\"$msoa\",\"area\":$area},\"geometry\":{\"type\":\"Point\",\"coordinates\":[$lon,$lat] } }";
	}
	$i++;
}
close($fh);

open(FILE,">",$ofile);
print FILE "{\n";
print FILE "\t\"type\":\"FeatureCollection\",\n";
print FILE "\t\"features\":[\n";
print FILE $out;
print FILE "\t]\n";
print FILE "}\n";
close(FILE);


open(FILE,">",$msoafile);
print FILE "msoa,brownfield area\n";
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
		}elsif($features[$f]->{'geometry'}->{'type'} eq "MultiPolygon"){
			$n = @{$features[$f]->{'geometry'}->{'coordinates'}};
			for($p = 0; $p < $n; $p++){
				($minlat,$maxlat,$minlon,$maxlon) = getBBox($minlat,$maxlat,$minlon,$maxlon,@{$features[$f]->{'geometry'}->{'coordinates'}[$p]});
			}
		}else{
			print "ERROR: Unknown geometry type $features[$f]->{'geometry'}->{'type'}\n";
		}
		# Set the bounding box
		$features[$f]->{'geometry'}{'bbox'} = {'lat'=>{'min'=>$minlat,'max'=>$maxlat},'lon'=>{'min'=>$minlon,'max'=>$maxlon}};
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
	
	for($f = 0; $f < @features; $f++){
		@gs = "";
		$ok = 0;
		# If we are in the bounding box
		if($lat >= $features[$f]->{'geometry'}{'bbox'}{'lat'}{'min'} && $lat <= $features[$f]->{'geometry'}{'bbox'}{'lat'}{'max'} && $lon >= $features[$f]->{'geometry'}{'bbox'}{'lon'}{'min'} && $lon <= $features[$f]->{'geometry'}{'bbox'}{'lon'}{'max'}){
			if($features[$f]->{'geometry'}->{'type'} eq "Polygon"){
				$ok = withinPolygon($lat,$lon,@{$features[$f]->{'geometry'}->{'coordinates'}});
			}else{
				$n = @{$features[$f]->{'geometry'}->{'coordinates'}};
				$ok = withinMultiPolygon($lat,$lon,@{$features[$f]->{'geometry'}->{'coordinates'}});
			}
			if($ok){
				return $features[$f]->{'properties'}->{'msoa11cd'};
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