"""Generate independent LightGBM expectations and reference route fixtures."""
import json
from pathlib import Path

from route_profile import RoadMatcher, build_profile
from runtime_model import SpeedModel


def main():
    root = Path(__file__).resolve().parents[2]
    directory = root / "output/utraffic_speed/runtime"
    metadata = json.loads((directory / "model.json").read_text(encoding="utf-8"))
    model = SpeedModel(metadata)
    matcher = RoadMatcher(json.loads((directory / "network.json").read_text(encoding="utf-8")))
    cases = json.loads((directory / "parity.json").read_text(encoding="utf-8"))
    maximum = 0
    for case in cases:
        vector = model.features_at(case["road"], case["at"])
        assert max(abs(a - b) for a, b in zip(vector, case["features"])) < 1e-10
        maximum = max(maximum, abs(model.predict(vector) - case["speed_kmh"]))
    assert maximum < 1e-8
    routes = root / "output/utraffic_speed/routes"
    benchmark = json.loads((routes / "benchmark.json").read_text(encoding="utf-8"))
    fixtures = []
    for name, data in benchmark["routes"].items():
        if not data["selected"]:
            continue
        route = json.loads((routes / f"{name}.json").read_text(encoding="utf-8"))["route"]
        for key in ("peak_hour", "off_peak_hour"):
            at = f"2020-12-16T{data['selected'][key]:02}:00:00+07:00"
            profile = build_profile(route, at, model, matcher)
            fixtures.append({"name": name + "_" + key, "route": route, "at": at, "expected": profile})
    # Crossing hour and midnight is a forecast-clock test, not a real data label.
    for at in ("2020-12-25T23:59:30+07:00", "2021-01-03T23:59:30+07:00"):
        route = fixtures[0]["route"]
        fixtures.append({"name": "boundary_" + at, "route": route, "at": at, "expected": build_profile(route, at, model, matcher)})
    (directory / "route_parity.json").write_text(json.dumps(fixtures, separators=(",", ":")), encoding="utf-8")
    print(json.dumps({"python_lightgbm_cases": len(cases), "maximum_speed_error": maximum, "route_cases": len(fixtures)}))


if __name__ == "__main__":
    main()
