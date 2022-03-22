# Updating data

Create the `MSOA.geojson` file and remove whitespace in it.

Next we process a brownfield sites file with:

```perl processBrownfieldSites.pl <file>```


/*
First create the `MSOA.sqlite` file:


The `input.vrt` file defines our layers.


ogr2ogr -f SQLite brownfield-sites.sqlite ../brownfield-sites.csv -dialect sqlite -sql "select * from brownfield-sites where geometry is not null" -oo X_POSSIBLE_NAMES=GeoX -oo Y_POSSIBLE_NAMES=GeoY -oo KEEP_GEOM_COLUMNS=NO -a_srs 'EPSG:25832'

```ogrinfo -sql "SELECT m.msoa11cd, sum(b.Hectares) as total_capacity from msoa m, brownfield b WHERE ST_INTERSECTS(m.geometry, b.geometry) group by m.msoa11cd" -dialect SQLITE input.vrt```


Create an SQLite version of the CSV:

```ogr2ogr -f SQLite brownfield.sqlite ../brownfield-sites.csv -oo X_POSSIBLE_NAMES=GeoX -oo Y_POSSIBLE_NAMES=GeoY -skipfailures -a_srs 'EPSG:4326'```


```ogrinfo -sql "SELECT m.msoa11cd, sum(b.Hectares) as total_capacity from msoa m, brownfield b WHERE ST_INTERSECTS(m.geometry, b.geometry) group by m.msoa11cd" -dialect SQLITE input.vrt```


ogr2ogr -sql "SELECT m.msoa11cd, b.Hectares from msoa m, brownfield b WHERE ST_INTERSECTS(m.geometry, b.geometry)" -dialect SQLITE -f GeoJSON output.geojson input.vrt

ogr2ogr -f GeoJSON brownfield.geojson brownfield.sqlite

*/