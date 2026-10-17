"""Capture publisher metadata, without authentication or dataset re-download."""
import json
import urllib.request
from pathlib import Path

URL = "https://www.kaggle.com/api/v1/datasets/view/thanhnguyen2612/traffic-flow-data-in-ho-chi-minh-city-viet-nam"


def main():
    directory = Path("output/utraffic_speed/sources")
    directory.mkdir(parents=True, exist_ok=True)
    request = urllib.request.Request(URL, headers={"User-Agent": "GiaoHang-UTraffic-Research/1.0"})
    with urllib.request.urlopen(request, timeout=20) as response:
        payload = json.load(response)
    (directory / "kaggle_metadata.json").write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"source_url": URL, "keys": list(payload),
                      "description": payload.get("description", ""), "files": payload.get("files", [])}, ensure_ascii=True, default=str)[:16000])


if __name__ == "__main__":
    main()
