# brownfield-land
Getting brownfield land locations

Steps:

1. Get [source.csv](https://github.com/digital-land/brownfield-land-collection/blob/main/collection/source.csv) and limit the rows to the most recent entry for each `local-authority-eng:*`. This should reduce it from over 1000 rows to around 300.
2. Find the endpoint URL for each row using [endpoints.csv](https://github.com/digital-land/brownfield-land-collection/blob/main/collection/endpoint.csv)
3. Download each URL and reject 404 errors or content that isn't CSV/XLSX.
4. Check if each URL is actually a CSV file (convert from XLSX if necessary)
5. Sanitise each row of each URL (check if it looks sensible - headers, do coordinates look reasonable?) and keep `CoordinateReferenceSystem`, `GeoX`, `GeoY`, `Hectares`, `SiteNameAddress` and `OrganisationURI`. Save those columns for the whole country as `brownfield-sites.csv`.
6. Load `brownfield-sites.csv` and:
  1. convert coordinates from OSGB to lat/lon.
  2. Find the GSS code for each `OrganisationURI` using the OpenDataCommunities API e.g. https://opendatacommunities.org/resource.json?uri=http%3A%2F%2Fopendatacommunities.org%2Fid%2Fmetropolitan-district-council%2Fleeds (there is potential that this may be out-of-date because Local Authority boundaries have changed but a particular brownfield site may still exist in a newer Local Authority)
9. Clip the whole dataset to each MSOA and find the sum of the `Hectares` for each. Save the MSOAs and total areas to `MSOAs.csv`.
10. Make LA-specific GeoJSON files of points.
