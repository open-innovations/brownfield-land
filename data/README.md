# Data

The Digital Land team at DHLUC maintain [a repository of Brownfield Land](https://github.com/digital-land/brownfield-land-collection) [sources](https://github.com/digital-land/brownfield-land-collection/blob/main/collection/source.csv) and [endpoints](https://github.com/digital-land/brownfield-land-collection/blob/main/collection/endpoint.csv). These two files give links to datasets published by local authorities (including National Park authorities) in a mix of CSV or XLSX files. The dataset includes multiple entries for each local authority.

The Digital Land team also [publish all the data from across local authorities](https://www.digital-land.info/dataset/brownfield-land) as [a single CSV file](https://www.digital-land.info/dataset/brownfield-land), as [paged GeoJSON](https://www.digital-land.info/entity.geojson?dataset=brownfield-land), and as [paged JSON](https://www.digital-land.info/entity.json?dataset=brownfield-land) (maximum of 500 entries per page). The data are released under the [Open Government Licence v3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/).

The script `getData.pl` will download the paged GeoJSON output and compile it into one large GeoJSON file at `brownfield-sites.geojson`. The script `processBrownfieldSites.pl` will use that file along with `msoas-fixed.geojson` to work out which MSOA each point is in, sum up the `hectares` values for each MSOA, and save the output to `brownfield-areas.csv`.

