# Offline Map

The Map tab renders entirely offline. The built-in world and US state boundaries
are compiled into Dart from public-domain Natural Earth 1:110m GeoJSON. The map
also draws a coordinate grid. There are no online tile URLs, geocoding services,
location-permission requests, or background tile downloads.

- **Me:** starts as a clearly labeled demo reference in Nashville, not a GPS fix.
  Use **Set my location** for coordinates/a gazetteer match, or **Place Me on map**.
- **Records:** saved address changes resolve against an embedded gazetteer of US
  cities, military bases, selected ZIP prefixes, and state centers. These matches
  are approximate centroids, not validated street addresses. Unknown addresses
  remain unmapped. Latitude/longitude fields or **Assign pin** set a precise point.
- **Relationships:** click a pin or a record in the panel to show straight-line
  Haversine distance and bearing from Me, plus the nearest visible records. Dashed
  lines connect the selection to the reference and its three nearest records.
  **Set as reference point** changes the comparison origin without moving Me.
- **Filters:** organizations, contacts, distance lines, and archived records can
  be toggled. Contact colors follow active/inactive/deceased profile state.
- **Navigation:** **View on Map** in record details selects the pin. **Open record**
  returns to the record (archived records open their edit form).

## Data sources and scope

- World: Natural Earth `ne_110m_admin_0_countries.geojson`
- US states: Natural Earth `ne_110m_admin_1_states_provinces.geojson`
- Source: https://github.com/nvkelso/natural-earth-vector/tree/master/geojson
- Public-domain terms: https://www.naturalearthdata.com/about/terms-of-use/

Boundaries are generalized reference geography. The built-in gazetteer is a small
approximate lookup, not a complete postal database. Distances are straight-line
estimates, not driving routes. This map uses built-in boundaries and a grid; it
does not display street or satellite imagery.
