import { storeGpsChunk } from "./gps.js";
import { runGpsHistoryFlush } from "./gps_scheduler.js";
import { appendHeaders, corsHeaders, json } from "./http.js";
import {
  createDownloadTicket,
  createUploadTicket,
  deleteInternalObject,
  deleteOwnedObject,
  downloadWithTicket,
  promoteAvatar,
  uploadWithTicket,
} from "./media.js";

export default {
  async scheduled(_controller, env, _ctx) {
    await runGpsHistoryFlush(env);
  },
  async fetch(request, env) {
    const origin = request.headers.get("origin");
    const cors = corsHeaders(origin, env.ALLOWED_ORIGINS);
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: cors });
    }

    try {
      const url = new URL(request.url);
      const response = await route(request, env, url);
      appendHeaders(response.headers, cors);
      return response;
    } catch (error) {
      const status = Number.isInteger(error?.status) ? error.status : 500;
      const message = status >= 500 ? "Internal server error" : error.message;
      const response = json({ error: message }, status);
      appendHeaders(response.headers, cors);
      return response;
    }
  },
};

async function route(request, env, url) {
  const key = `${request.method} ${url.pathname}`;
  switch (key) {
    case "GET /health":
      return json({ ok: true });
    case "POST /v1/media/upload-ticket":
      return createUploadTicket(request, env);
    case "PUT /v1/ticket/upload":
      return uploadWithTicket(request, env, url);
    case "POST /v1/media/download-ticket":
      return createDownloadTicket(request, env);
    case "GET /v1/ticket/download":
      return downloadWithTicket(env, url);
    case "POST /v1/media/delete":
      return deleteOwnedObject(request, env);
    case "POST /v1/gps/chunks":
      return storeGpsChunk(request, env);
    case "POST /v1/internal/promote-avatar":
      return promoteAvatar(request, env);
    case "POST /v1/internal/delete":
      return deleteInternalObject(request, env);
    default:
      return json({ error: "Not found" }, 404);
  }
}
