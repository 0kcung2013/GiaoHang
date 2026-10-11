"""Features available when computing ETA; never include the speed label."""
import pandas as pd


def features(frame, roads, include_road=True):
    time = pd.to_datetime(frame.time)
    result = pd.DataFrame(index=frame.index)
    if include_road:
        result["road"] = pd.Categorical(frame.road, categories=roads)
    result["hour"] = time.dt.hour + time.dt.minute / 60
    result["weekday"] = time.dt.dayofweek
    result["weekend"] = (time.dt.dayofweek >= 5).astype(int)
    return result
