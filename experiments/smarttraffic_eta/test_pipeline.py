import io
import json
import zipfile

import numpy as np
import pandas as pd
import pytest

from aggregate import clean_motorbikes
from model import features
from source import project_record, records_from_chunks, zip_chunks
from demo_eta import predict_route


@pytest.mark.parametrize("array", [True, False])
def test_unicode_records_across_byte_boundaries(array):
    records = [{"street": "Đường Nguyễn Huệ", "speed": 31}, {"speed": 0}]
    text = json.dumps(records, ensure_ascii=False) if array else "\n".join(json.dumps(r, ensure_ascii=False) for r in records)
    assert list(records_from_chunks(bytes([b]) for b in text.encode())) == records


def test_zip_crc_is_checked():
    data = io.BytesIO()
    with zipfile.ZipFile(data, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("traffic.json", '[{"speed": 30}]')
    original = data.getvalue()
    assert list(records_from_chunks(zip_chunks(io.BytesIO(original), "traffic.json"))) == [{"speed": 30}]
    corrupted = bytearray(original)
    corrupted[14] ^= 1  # Change the expected CRC, leaving deflated bytes intact.
    with pytest.raises(ValueError, match="CRC"):
        list(zip_chunks(io.BytesIO(corrupted), "traffic.json"))
    with pytest.raises(ValueError, match="Truncated"):
        list(zip_chunks(io.BytesIO(original[:40]), "traffic.json"))


def test_truncated_json_array_is_not_accepted():
    with pytest.raises(ValueError, match="Truncated"):
        list(records_from_chunks([b'[{"speed":30}']))


def test_projection_does_not_retain_contacts_or_estimated_eta():
    row = project_record({"owner": {"email": "private@example.test"},
                          "estimated_time_of_arrival": {"eta": "future"}, "speed_kmph": 30})
    assert "owner" not in row and "estimated_time_of_arrival" not in row
    assert row["speed_kmph"] == 30


def test_filter_keeps_stopped_motorbikes_and_rejects_invalid_rows():
    base = {"vehicle_type": "Motorbike", "timestamp": "2024-04-01 08:00:00",
            "street": "A", "district": "B", "latitude": 10.77, "longitude": 106.67}
    frame = pd.DataFrame([{**base, "speed_kmph": 0}, {**base, "speed_kmph": 35},
                          {**base, "speed_kmph": -1}, {**base, "speed_kmph": 200},
                          {**base, "speed_kmph": 30, "vehicle_type": "Car"}])
    assert clean_motorbikes(frame).speed_kmph.tolist() == [0, 35]


def test_unknown_road_and_speed_label_do_not_leak_into_features():
    frame = pd.DataFrame({"road": ["known", "new"], "time": pd.to_datetime(["2024-04-01 08:00", "2024-04-02 19:30"]), "speed_kmph": [10, 99]})
    result = features(frame, ["known"])
    assert "speed_kmph" not in result
    assert pd.isna(result.road.iloc[1])
    assert result.hour.tolist() == [8, 19.5]


def test_demo_sums_both_legs_and_three_service_intervals():
    class ConstantSpeed:
        def predict(self, frame):
            return np.full(len(frame), 30.)

    route = {"distance": 3000, "legs": [
        {"distance": 1000, "steps": [{"distance": 1000, "name": "A"}]},
        {"distance": 2000, "steps": [{"distance": 2000, "name": "B"}]},
    ]}
    artifact = {"roads": [], "include_road": False, "model": ConstantSpeed()}
    result = predict_route(route, artifact, pd.Timestamp("2026-10-12T08:00:00+07:00"))
    assert result["total_minutes"] == pytest.approx(21)
    assert result["service_minutes"] == 15
    assert result["predicted_delivery_at"] == "2026-10-12T08:21:00+07:00"
