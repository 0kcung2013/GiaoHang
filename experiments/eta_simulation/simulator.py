"""Declared synthetic traffic world. Targets never come from the trained model."""
import math

SIMULATOR_VERSION = "hcm_motorcycle_synthetic_world_v1"


def expected_seconds(features):
    f = features
    hour = f["hour"]
    morning = math.exp(-.5 * ((hour - 7.8) / 1.05) ** 2)
    evening = math.exp(-.5 * ((hour - 17.5) / 1.25) ** 2)
    peak = max(morning, evening) * (.48 if f["weekend"] else 1.0)
    minor = f["minor_road_share"]
    # Coefficients define a demo, not measured Vietnamese motorcycle behavior.
    cruising = f["baseline_minutes"] * 60 * (.98 + .10 * minor + peak * (.35 + .35 * minor))
    turns = f["turns_per_km"] * f["distance_km"] * (1.8 + 2.2 * peak)
    signals = min(16, f["signal_density"]) * f["distance_km"] * (1.2 + 2.5 * peak)
    junctions = min(70, f["junction_density"]) * f["distance_km"] * (.07 + .13 * peak)
    return cruising + turns + signals + junctions


def simulate_seconds(features, rng):
    # A small unobservable variation creates an irreducible test error.
    factor = min(1.14, max(.86, float(rng.normal(1, .035))))
    return expected_seconds(features) * factor
