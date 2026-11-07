# Operating-area reference data attribution

Boundaries: **geoBoundaries gbOpen / OCHA ROAP / Government of Viet Nam**,
Vietnam ADM1 and ADM2, represented year **2020**, geoBoundaries commit `9469f09`.

- https://www.geoboundaries.org/
- https://github.com/wmgeolab/geoBoundaries/tree/9469f09/releaseData/gbOpen/VNM
- https://data.humdata.org/dataset/viet-nam-administrative-boundaries-polygon-polyline
- License: **Creative Commons Attribution 3.0 IGO (CC BY 3.0 IGO)**:
  https://creativecommons.org/licenses/by/3.0/igo/

Changes: matched names to legacy province/district codes, filtered unmatched
regions, topology-preserving simplification at 0.00005 degrees, rounded to seven
decimal places and repaired polygon topology for operational point containment.
These are operational reference zones, not a statement of current legal borders.
No endorsement by the data providers is implied.

Names and codes: Province Open API v1 / VietnamProvinces, snapshot 2026-11-05:
https://provinces.open-api.vn/api/v1/?depth=2

See `coverage.json` for regions without an unambiguous boundary match and
`docs/handoff/driver_dispatch_preferences.md` for setup and limitations.
