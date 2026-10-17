"""Audited historical labels and static directed road attributes; no app GPS."""
from __future__ import annotations

import hashlib
from pathlib import Path

import numpy as np
import pandas as pd

SOURCE_URL = "https://www.kaggle.com/datasets/thanhnguyen2612/traffic-flow-data-in-ho-chi-minh-city-viet-nam"
TIMEZONE = "Asia/Ho_Chi_Minh"
SOURCE_FILES = ("nodes.csv", "segments.csv", "streets.csv", "segment_status.csv", "train.csv")
ROAD_FEATURES = ["midpoint_lat", "midpoint_lng", "length_m", "max_speed", "max_speed_missing", "level", "level_missing", "type_code", "bearing_sin", "bearing_cos"]


def sha256(path: Path) -> str:
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def load_network(data_dir: Path) -> tuple[pd.DataFrame, dict]:
    nodes = pd.read_csv(data_dir / "nodes.csv").rename(columns={"_id": "node_id", "long": "lng"})
    streets = pd.read_csv(data_dir / "streets.csv").rename(columns={"_id": "street_id"})
    segments = pd.read_csv(data_dir / "segments.csv").rename(columns={"_id": "segment_id", "created_at": "network_created_at", "updated_at": "network_updated_at"})
    audit = {}
    for name, frame, key in (("nodes", nodes, "node_id"), ("streets", streets, "street_id"), ("segments", segments, "segment_id")):
        audit[name] = {"rows": len(frame), "duplicate_ids": int(frame[key].duplicated().sum())}
        if frame[key].duplicated().any():
            raise ValueError(f"Ambiguous network primary key: {name}")
    roads = segments.merge(nodes.rename(columns={"node_id": "s_node_id", "lat": "start_lat", "lng": "start_lng"}), on="s_node_id", how="left", validate="many_to_one")
    roads = roads.merge(nodes.rename(columns={"node_id": "e_node_id", "lat": "end_lat", "lng": "end_lng"}), on="e_node_id", how="left", validate="many_to_one")
    roads = roads.merge(streets[["street_id", "max_velocity", "level", "type", "name"]], on="street_id", how="left", suffixes=("", "_street"), validate="many_to_one", indicator=True)
    audit["missing_start_node"] = int(roads.start_lat.isna().sum())
    audit["missing_end_node"] = int(roads.end_lat.isna().sum())
    audit["missing_street"] = int(roads._merge.eq("left_only").sum())
    roads["midpoint_lat"] = (roads.start_lat + roads.end_lat) / 2
    roads["midpoint_lng"] = (roads.start_lng + roads.end_lng) / 2
    roads["length_m"] = pd.to_numeric(roads["length"], errors="coerce")
    roads["max_speed"] = pd.to_numeric(roads.max_velocity, errors="coerce").fillna(pd.to_numeric(roads.max_velocity_street, errors="coerce"))
    roads["level"] = pd.to_numeric(roads.street_level, errors="coerce").fillna(roads.level)
    # Missing static metadata is explicit, never an excuse to discard congestion labels.
    for field in ("max_speed", "level"):
        missing = ~np.isfinite(roads[field]) | roads[field].le(0)
        roads[field + "_missing"] = missing.astype(float)
        audit[field + "_missing"] = int(missing.sum())
        roads.loc[missing, field] = 0
    road_types = sorted(roads.street_type.fillna(roads["type"]).dropna().unique())
    audit["type_encoding"] = {value: index + 1 for index, value in enumerate(road_types)}
    roads["type_code"] = roads.street_type.fillna(roads["type"]).map(audit["type_encoding"]).fillna(0)
    dx = (roads.end_lng - roads.start_lng) * np.cos(np.radians(roads.midpoint_lat))
    dy = roads.end_lat - roads.start_lat
    magnitude = np.hypot(dx, dy)
    roads["bearing_sin"] = dx / magnitude
    roads["bearing_cos"] = dy / magnitude
    roads["street_name"] = roads.street_name.fillna(roads["name"]).fillna("")
    # Static deterministic IDs, never computed from velocity or LOS.
    roads["segment_code"] = roads.segment_id.map({v: i for i, v in enumerate(sorted(roads.segment_id))})
    roads["street_code"] = roads.street_id.map({v: i for i, v in enumerate(sorted(roads.street_id.dropna().unique()))})
    valid_geometry = roads.start_lat.between(-90, 90) & roads.end_lat.between(-90, 90) & roads.start_lng.between(-180, 180) & roads.end_lng.between(-180, 180) & magnitude.gt(0)
    valid_attributes = np.isfinite(roads[ROAD_FEATURES]).all(axis=1) & roads.length_m.gt(0)
    audit["invalid_geometry"] = int((~valid_geometry).sum())
    audit["invalid_attributes"] = int((~valid_attributes).sum())
    roads["valid_road"] = valid_geometry & valid_attributes
    audit["valid_roads"] = int(roads.valid_road.sum())
    return roads, audit


def load_labels(data_dir: Path) -> tuple[pd.DataFrame, pd.DataFrame, dict]:
    roads, network_audit = load_network(data_dir)
    labels = pd.read_csv(data_dir / "segment_status.csv").rename(columns={"_id": "observation_id"})
    labels["source_row"] = np.arange(len(labels)) + 2
    audit = {"source_url": SOURCE_URL, "dataset_version": 6, "timezone": TIMEZONE,
             "velocity_unit": {"working_unit": "km/h", "publisher_explicit_unit_verified": False,
                               "reason": "inference from max_velocity free-flow scale and velocity/maximum relation in the publisher data card; no multiply-by-3.6 conversion"},
             "network": network_audit, "raw_rows": len(labels),
             "duplicate_observation_ids": int(labels.observation_id.duplicated().sum()),
             "source_sha256": {name: sha256(data_dir / name) for name in SOURCE_FILES}, "excluded": {}}
    labels["updated_at"] = pd.to_datetime(labels.updated_at, utc=True, errors="coerce", format="mixed")
    labels["velocity"] = pd.to_numeric(labels.velocity, errors="coerce")

    def remove(reason, mask):
        nonlocal labels
        audit["excluded"][reason] = int(mask.sum())
        labels = labels.loc[~mask].copy()

    remove("invalid_time_or_velocity", labels.updated_at.isna() | ~np.isfinite(labels.velocity))
    # Plausibility ceiling is a declared analytical rule, not an assertion of sensor quality.
    remove("velocity_outside_0_90", ~labels.velocity.between(0, 90))
    remove("exact_segment_time_velocity_duplicates", labels.duplicated(["segment_id", "updated_at", "velocity"]))
    conflicts = labels.groupby(["segment_id", "updated_at"]).velocity.transform("nunique").gt(1)
    remove("conflicting_segment_time", conflicts)
    labels = labels.merge(roads, on="segment_id", how="left", validate="many_to_one", indicator="road_join")
    remove("unjoined_segment", labels.road_join.eq("left_only"))
    remove("invalid_road_geometry_or_attributes", ~labels.valid_road.fillna(False).astype(bool))
    labels["local_time"] = labels.updated_at.dt.tz_convert(TIMEZONE)
    labels["local_date"] = labels.local_time.dt.strftime("%Y-%m-%d")
    labels["hour_bin"] = labels.local_time.dt.hour
    labels = labels.sort_values(["updated_at", "segment_id", "observation_id"]).reset_index(drop=True)
    audit.update({"kept_rows": len(labels), "max_speed_missing_rows": int(labels.max_speed_missing.sum()), "zero_velocity_rows": int(labels.velocity.eq(0).sum()),
                  "positive_below_1": int(labels.velocity.between(0, 1, inclusive="neither").sum()),
                  "positive_below_3": int(labels.velocity.between(0, 3, inclusive="neither").sum()),
                  "segments_with_labels": int(labels.segment_id.nunique()), "local_days": int(labels.local_date.nunique()),
                  "start_utc": labels.updated_at.min().isoformat(), "end_utc": labels.updated_at.max().isoformat(),
                  "velocity_quantiles": {str(k): float(v) for k, v in labels.velocity.quantile([0, .01, .1, .25, .5, .75, .9, .99, 1]).items()}})
    assert audit["raw_rows"] == audit["kept_rows"] + sum(audit["excluded"].values())
    return labels, roads, audit


def chronological_split(labels: pd.DataFrame) -> tuple[dict[str, pd.DataFrame], dict]:
    """70/15/15 by cumulative observations, rounded to whole local dates."""
    counts = labels.groupby("local_date").size().sort_index()
    cumulative = counts.cumsum()
    validation_day = cumulative.index[np.searchsorted(cumulative.values, len(labels) * .70)]
    test_day = cumulative.index[np.searchsorted(cumulative.values, len(labels) * .85)]
    splits = {"train": labels[labels.local_date.lt(validation_day)].copy(),
              "validation": labels[labels.local_date.ge(validation_day) & labels.local_date.lt(test_day)].copy(),
              "test": labels[labels.local_date.ge(test_day)].copy()}
    if any(frame.empty for frame in splits.values()):
        raise ValueError("Not enough chronological dates for three disjoint splits")
    metadata = {"validation_start_local": validation_day, "test_start_local": test_day, "splits": {}}
    train_ids = set(splits["train"].segment_id)
    for name, frame in splits.items():
        metadata["splits"][name] = {"rows": len(frame), "days": frame.local_date.nunique(),
                                  "start_utc": frame.updated_at.min().isoformat(), "end_utc": frame.updated_at.max().isoformat(),
                                  "segments": frame.segment_id.nunique(), "unseen_train_segment_rows": int((~frame.segment_id.isin(train_ids)).sum())}
    assert splits["train"].updated_at.max() < splits["validation"].updated_at.min()
    assert splits["validation"].updated_at.max() < splits["test"].updated_at.min()
    return splits, metadata
