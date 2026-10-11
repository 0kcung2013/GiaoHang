"""Stream public Kaggle JSON without retaining simulated personal information."""
from __future__ import annotations

import codecs
import json
import struct
import urllib.request
import zlib

DATASET = "ren294/iot-car-hcmcity"
DATASET_VERSION = 1


def records_from_chunks(chunks):
    """Read a JSON array or newline-delimited JSON with bounded buffering."""
    decoder = json.JSONDecoder()
    utf8 = codecs.getincrementaldecoder("utf-8-sig")()
    buffer = ""
    array_mode = None
    array_closed = False
    for chunk in chunks:
        buffer += utf8.decode(chunk)
        while True:
            if array_mode is None and buffer.strip():
                array_mode = buffer.lstrip().startswith("[")
            buffer = buffer.lstrip(" \r\n\t,[")
            if buffer.startswith("]"):
                if not array_mode or array_closed:
                    raise ValueError("Unexpected array terminator")
                array_closed = True
                buffer = buffer[1:]
                continue
            if not buffer:
                break
            if array_closed:
                raise ValueError("Data after JSON array")
            try:
                record, end = decoder.raw_decode(buffer)
            except json.JSONDecodeError:
                if len(buffer) > 2_000_000:
                    raise ValueError("Record exceeds buffer limit or unsupported JSON format")
                break
            if not isinstance(record, dict):
                raise ValueError("Expected JSON objects")
            yield record
            buffer = buffer[end:]
    buffer += utf8.decode(b"", final=True)
    if buffer.strip(" \r\n\t,]"):
        raise ValueError("Truncated JSON stream")
    if array_mode and not array_closed:
        raise ValueError("Truncated JSON array")


def read_exact(stream, length):
    data = bytearray()
    while len(data) < length:
        block = stream.read(length - len(data))
        if not block:
            raise ValueError("Truncated ZIP header")
        data.extend(block)
    return bytes(data)


def zip_chunks(response, expected_name):
    """Kaggle serves one deflated JSON entry, potentially using ZIP64 sizes."""
    header = read_exact(response, 30)
    signature, version, flags, method, time, date, crc, compressed, size, name_len, extra_len = struct.unpack("<4s5H3I2H", header)
    if signature != b"PK\x03\x04" or method != 8 or flags & 9:
        raise ValueError("Expected unencrypted deflated ZIP with CRC in local header")
    name = read_exact(response, name_len).decode("utf-8")
    read_exact(response, extra_len)
    if name != expected_name:
        raise ValueError("Unexpected archive member")
    inflater = zlib.decompressobj(-15)
    checksum = 0
    while not inflater.eof:
        block = response.read(65536)
        if not block:
            raise ValueError("Truncated ZIP body")
        data = inflater.decompress(block)
        checksum = zlib.crc32(data, checksum)
        yield data
    if not flags & 8 and checksum != crc:
        raise ValueError("ZIP CRC mismatch")


def remote_records(filename):
    url = f"https://www.kaggle.com/api/v1/datasets/download/{DATASET}/{filename}?datasetVersionNumber={DATASET_VERSION}"
    with urllib.request.urlopen(url, timeout=120) as response:
        yield from records_from_chunks(zip_chunks(response, filename))


def project_record(record):
    """Only fields relevant to traffic analysis; exclude owner/contact/ETA."""
    road = record.get("road") or {}
    coords = record.get("coordinates") or {}
    return {
        "timestamp": record.get("timestamp"),
        "street": road.get("street"), "district": road.get("district"),
        "city": road.get("city"),
        "latitude": coords.get("latitude"), "longitude": coords.get("longitude"),
        "speed_kmph": record.get("speed_kmph"),
        "vehicle_type": record.get("vehicle_type"),
    }
