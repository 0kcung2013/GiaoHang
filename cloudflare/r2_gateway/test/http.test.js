import assert from "node:assert/strict";
import test from "node:test";

import { corsHeaders } from "../src/http.js";

const configuredOrigins = "http://localhost:*,http://127.0.0.1:*";

test("CORS allows the random localhost port used by flutter run", () => {
  const headers = corsHeaders("http://localhost:54321", configuredOrigins);

  assert.equal(
    headers["access-control-allow-origin"],
    "http://localhost:54321",
  );
});

test("CORS allows loopback IP but rejects lookalike and HTTPS origins", () => {
  assert.equal(
    corsHeaders("http://127.0.0.1:62000", configuredOrigins)[
      "access-control-allow-origin"
    ],
    "http://127.0.0.1:62000",
  );
  assert.equal(
    corsHeaders("http://localhost.example.com:54321", configuredOrigins)[
      "access-control-allow-origin"
    ],
    undefined,
  );
  assert.equal(
    corsHeaders("https://localhost:54321", configuredOrigins)[
      "access-control-allow-origin"
    ],
    undefined,
  );
});
