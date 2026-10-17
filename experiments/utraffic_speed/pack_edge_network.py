"""Generate a lossless Edge artifact; never overwrite the deployed source."""
import base64
import gzip
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[2]
raw = (root / 'output/utraffic_speed/runtime/network.json').read_bytes()
compressed = gzip.compress(raw, compresslevel=9, mtime=0)
assert gzip.decompress(compressed) == raw
payload = base64.b64encode(compressed).decode()
source = '''// Generated lossless UTraffic network. Decode once per Edge worker.
const payload = PAYLOAD;
const compressed = Uint8Array.from(atob(payload), c => c.charCodeAt(0));
const stream = new Blob([compressed]).stream().pipeThrough(new DecompressionStream('gzip'));
export const roadNetwork = JSON.parse(await new Response(stream).text());
export const roadNetworkSha256 = HASH;
'''.replace('PAYLOAD', json.dumps(payload)).replace('HASH', json.dumps(hashlib.sha256(raw).hexdigest()))
target = root / 'output/utraffic_speed/runtime/delivery_eta_road_network_data.mjs'
target.write_text(source, encoding='utf-8')
report = {'uncompressed_json_bytes': len(raw), 'gzip_bytes': len(compressed),
          'source_bytes': target.stat().st_size, 'uncompressed_sha256': hashlib.sha256(raw).hexdigest()}
(root / 'output/utraffic_speed/edge_network_pack.json').write_text(json.dumps(report, indent=2))
print(json.dumps(report))
