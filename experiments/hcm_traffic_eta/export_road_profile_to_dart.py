from __future__ import annotations

import argparse
import base64
import struct
from pathlib import Path

import pandas as pd


ENTRY_STRUCT = struct.Struct("<fffff")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Export compact UTraffic road profiles for Flutter ETA inference."
    )
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    return parser.parse_args()


def dart_source(payload: str, row_count: int) -> str:
    chunks = [payload[index : index + 160] for index in range(0, len(payload), 160)]
    literals = "\n".join(f"  '{chunk}'" for chunk in chunks)
    return f"""// GENERATED FILE. Do not edit by hand.
// Source: UTraffic TP.HCM historical road profile.
// Entries: {row_count}.

const deliveryEtaAiRoadProfileCount = {row_count};
const deliveryEtaAiRoadProfilePayload =
{literals};
"""


def main() -> None:
    args = parse_args()
    rows = pd.read_csv(args.input)
    required = [
        "route_midpoint_lat",
        "route_midpoint_lng",
        "road_length_meters",
        "road_speed_limit_kmh",
        "road_level",
        "historical_speed_ratio",
    ]
    missing = set(required) - set(rows.columns)
    if missing:
        raise ValueError(f"Missing profile columns: {sorted(missing)}")

    payload = bytearray(b"RPF1")
    payload.extend(struct.pack("<H", len(rows)))
    for row in rows.itertuples(index=False):
        payload.extend(
            ENTRY_STRUCT.pack(
                float(row.route_midpoint_lat),
                float(row.route_midpoint_lng),
                float(row.road_length_meters),
                float(row.road_speed_limit_kmh),
                float(row.road_level),
            )
        )
        # The last value is stored separately to keep the on-device structure
        # explicit and aligned with the model feature contract.
        payload.extend(struct.pack("<f", float(row.historical_speed_ratio)))

    encoded = base64.b64encode(payload).decode("ascii")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        dart_source(encoded, len(rows)), encoding="utf-8", newline="\n"
    )
    print(
        f"Exported {len(rows):,} road profiles to {args.output} "
        f"({args.output.stat().st_size:,} bytes)."
    )


if __name__ == "__main__":
    main()
