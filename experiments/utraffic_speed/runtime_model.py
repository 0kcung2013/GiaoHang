"""Small reference runtime, identical exported numeric tree contract."""
import base64
import math
import struct
from datetime import datetime, timedelta, timezone


class SpeedModel:
    def __init__(self, metadata):
        self.metadata = metadata
        payload = base64.b64decode(metadata["payload"])
        if payload[:4] != b"ETA1":
            raise ValueError("Invalid model")
        count = struct.unpack_from("<H", payload, 4)[0]
        offset, self.trees = 6, []
        for _ in range(count):
            length = struct.unpack_from("<H", payload, offset)[0]
            offset += 2
            nodes = []
            for _ in range(length):
                nodes.append(struct.unpack_from("<hdhhB", payload, offset))
                offset += 15
            self.trees.append(nodes)
        if offset != len(payload):
            raise ValueError("Trailing model data")

    def features_at(self, road, at):
        local = datetime.fromisoformat(at.replace("Z", "+00:00")).astimezone(timezone(timedelta(hours=7)))
        hour = local.hour + local.minute / 60
        values = dict(road, hour=hour, weekday=local.weekday(), weekend=float(local.weekday() >= 5),
                      hour_sin=math.sin(hour * 2 * math.pi / 24), hour_cos=math.cos(hour * 2 * math.pi / 24))
        return [values[name] for name in self.metadata["feature_names"]]

    def predict(self, vector):
        if len(vector) != len(self.metadata["feature_names"]) or not all(math.isfinite(v) for v in vector):
            raise ValueError("Invalid features")
        result = 0
        for nodes in self.trees:
            node = nodes[0]
            while node[0] >= 0:
                node = nodes[node[2] if vector[node[0]] <= node[1] else node[3]]
            result += node[1]
        if self.metadata["target"] == "log1p":
            result = math.expm1(result)
        return min(self.metadata["maximum_speed_kmh"], max(self.metadata["minimum_speed_kmh"], result))

    def speed_at(self, road, at):
        return self.predict(self.features_at(road, at))
