"""Prepare dependency-complete MCP payloads; never call a deployment API."""
import json
import re
from pathlib import Path


def main():
    root = Path(__file__).resolve().parents[2]
    directory = root / "output/eta_simulation"
    shared = directory / "edge/_shared"
    tests = (root / "supabase/functions/_shared/delivery_eta_test.mjs").read_text(encoding="utf-8")
    tests = tests.replace("'./delivery_eta_traffic.mjs'", "'../../../../supabase/functions/_shared/delivery_eta_traffic.mjs'")
    (shared / "delivery_eta_business_test.mjs").write_text(tests, encoding="utf-8")
    demo = (root / "supabase/functions/_shared/delivery_eta_demo_test.mjs").read_text(encoding="utf-8")
    demo = demo.replace("'./delivery_eta_traffic.mjs'", "'./delivery_eta_synthetic.mjs'")
    demo = demo.replace("'../../../apps/", "'../../../../apps/")
    demo = demo.replace("route adapter uses the progressive profile across hour boundaries", "route adapter and whole-route model share the same forecast time")
    (shared / "delivery_eta_demo_test.mjs").write_text(demo, encoding="utf-8")
    packages = []
    for name in ["accept-driver-order", "refresh-order-eta"]:
        destination = directory / "edge" / name
        destination.mkdir(parents=True, exist_ok=True)
        for original in (root / "supabase/functions" / name).glob("*"):
            if original.suffix in {".ts", ".mjs"} and "_test" not in original.name:
                source = original.read_text(encoding="utf-8")
                source = source.replace("createRoadRedis(name => Deno.env.get(name))", "createRoadRedis((name: string) => Deno.env.get(name))")
                (destination / original.name).write_text(source, encoding="utf-8")
        entry, files = f"supabase/functions/{name}/index.ts", {}

        def visit(file):
            if file in files:
                return
            relative = Path(file).relative_to("supabase/functions")
            candidate = directory / "edge" / relative
            source = (candidate if candidate.exists() else root / file).read_text(encoding="utf-8")
            if not candidate.exists():
                candidate.parent.mkdir(parents=True, exist_ok=True)
                candidate.write_text(source, encoding="utf-8")
            files[file] = source
            for match in re.finditer(r'(?:from\s+|import\s*)["\']([^"\']+)["\']', source):
                target = match.group(1)
                if target.startswith("."):
                    resolved = (root / Path(file).parent / target).resolve().relative_to(root).as_posix()
                    visit(resolved)

        visit(entry)
        packages.append({"project_id": "erlpzwfbpjogvaulcxni", "name": name, "verify_jwt": True,
                         "entrypoint_path": entry, "files": [{"name": file, "content": source} for file, source in files.items()]})
    (directory / "deploy_packages.json").write_text(json.dumps(packages, ensure_ascii=False), encoding="utf-8")
    print(json.dumps([{"name": p["name"], "files": len(p["files"]), "bytes": sum(len(f["content"].encode()) for f in p["files"])} for p in packages]))


if __name__ == "__main__":
    main()
