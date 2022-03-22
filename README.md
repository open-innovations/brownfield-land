# brownfield-land
Getting brownfield land locations

Steps:

1. Get [source.csv](https://github.com/digital-land/brownfield-land-collection/blob/main/collection/source.csv) and limit the rows to the most recent entry for each `local-authority-eng:*`. This should reduce it from over 1000 rows to around 300.
2. Find the endpoint URL for each row using [endpoints.csv](https://github.com/digital-land/brownfield-land-collection/blob/main/collection/endpoint.csv)
3. Grab each URL
4. Check if each URL is actually a CSV file (convert from XLSX if necessary)
5. Sanitise each row of each URL (check if it looks sensible - headers, do coordinates look reasonable?) and keep `CoordinateReferenceSystem`, `GeoX`, `GeoY`, `Hectares`.
6. Convert coordinates from OSGB to lat/lon
7. Find sum of areas for each MSOA.
8. Make LA-specific GeoJSON files.
