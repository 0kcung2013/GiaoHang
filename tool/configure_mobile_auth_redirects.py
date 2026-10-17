"""Merge mobile/preview callbacks into DATN Auth, preserving existing URLs.

Requires a Supabase management token with access to DATN (not an anon key).
Token is read from SUPABASE_ACCESS_TOKEN or a hidden prompt with --prompt-token.
Default mode only previews additions. --apply writes and reads back the result.
"""

import argparse
import getpass
import json
import os
import sys
import urllib.error
import urllib.request

PROJECT_REF = "erlpzwfbpjogvaulcxni"
CALLBACKS = (
    "com.datn.giaohang.customer://login-callback",
    "http://localhost:8081",
    "http://localhost:8082",
    "http://127.0.0.1:8081",
    "http://127.0.0.1:8082",
)


def merge_redirects(existing):
    urls = [url.strip() for url in (existing or "").split(",") if url.strip()]
    return list(dict.fromkeys([*urls, *CALLBACKS]))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--prompt-token", action="store_true")
    args = parser.parse_args()
    token = os.environ.get("SUPABASE_ACCESS_TOKEN")
    if not token and args.prompt_token:
        token = getpass.getpass("Supabase management token (hidden): ")
    if not token:
        sys.exit("Missing management access: set SUPABASE_ACCESS_TOKEN or use --prompt-token. No changes made.")

    endpoint = f"https://api.supabase.com/v1/projects/{PROJECT_REF}/config/auth"

    def request(method="GET", body=None):
        req = urllib.request.Request(
            endpoint,
            method=method,
            headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
            data=json.dumps(body).encode() if body is not None else None,
        )
        with urllib.request.urlopen(req, timeout=30) as response:
            return json.load(response)

    try:
        current = request()
        urls = merge_redirects(current.get("uri_allow_list"))
        print(json.dumps({"project": PROJECT_REF, "redirect_urls": urls}, indent=2))
        if not args.apply:
            print("Preview only. Use --apply to save.")
            return
        # Never send back the full Auth response: it includes provider secrets.
        existing = {url.strip() for url in (current.get("uri_allow_list") or "").split(",")}
        if not set(CALLBACKS).issubset(existing):
            request("PATCH", {"uri_allow_list": ",".join(urls)})
        verified = request()
        actual = {url.strip() for url in (verified.get("uri_allow_list") or "").split(",")}
        if not set(urls).issubset(actual):
            sys.exit("Saved response did not retain all URLs. Verification failed.")
        print("Saved and verified callback URLs. Google enabled:", verified.get("external_google_enabled"))
    except urllib.error.HTTPError as error:
        sys.exit(f"Management API returned HTTP {error.code}. Check access to DATN. Response details omitted to protect secrets.")


if __name__ == "__main__":
    main()
