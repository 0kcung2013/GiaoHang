import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

import {
  executeDriverProfileApproval,
  type PreparedApproval,
} from "./approval_flow.ts";

const requestFilesBucket = "driver-profile-request-files";
const avatarsBucket = "driver-avatars";
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const allowedExtensions = new Set(["jpg", "jpeg", "png", "webp"]);

class ApprovalHttpError extends Error {
  constructor(
    readonly code: string,
    readonly status: number,
  ) {
    super(code);
  }
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return cors(new Response(null));
  if (request.method !== "POST") {
    return json({ error: "METHOD_NOT_ALLOWED" }, 405);
  }

  try {
    const authorization = request.headers.get("Authorization");
    if (!authorization) throw new ApprovalHttpError("AUTH_REQUIRED", 401);

    const supabaseUrl = requiredEnv("SUPABASE_URL");
    const anonKey = requiredEnv("SUPABASE_ANON_KEY");
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
    });
    const { data: { user }, error: userError } = await userClient.auth
      .getUser();
    if (userError || !user) {
      throw new ApprovalHttpError("AUTH_REQUIRED", 401);
    }

    const { data: actor, error: actorError } = await userClient
      .from("users")
      .select("role")
      .eq("id", user.id)
      .maybeSingle();
    if (actorError || actor?.role !== "admin") {
      throw new ApprovalHttpError("ADMIN_ROLE_REQUIRED", 403);
    }

    const body = await parseBody(request);
    const requestId = body.request_id?.trim() ?? "";
    if (!uuidPattern.test(requestId)) {
      throw new ApprovalHttpError("INVALID_REQUEST_ID", 400);
    }

    // The service key is only read after the caller JWT and database role have
    // both been verified.
    const serviceKey = requiredEnv("SUPABASE_SERVICE_ROLE_KEY");
    const service = createClient(supabaseUrl, serviceKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const result = await executeDriverProfileApproval(requestId, {
      prepare: async (id): Promise<PreparedApproval> => {
        const { data, error } = await service.rpc(
          "prepare_driver_profile_change_approval",
          { p_request_id: id, p_admin_id: user.id },
        );
        if (error) throw error;
        const row = asRecord(data);
        if (row.status === "approved") {
          throw new ApprovalHttpError("ALREADY_APPROVED", 200);
        }
        if (row.status === "conflicted") {
          throw new ApprovalHttpError("PROFILE_CHANGED", 409);
        }
        if (row.status !== "applying") {
          throw new ApprovalHttpError("INVALID_APPROVAL_STATE", 409);
        }
        return {
          requestId: requiredString(row.request_id, "INVALID_PREPARE_RESULT"),
          userId: requiredString(row.user_id, "INVALID_PREPARE_RESULT"),
          oldEmail: nullableString(row.old_email),
          newEmail: nullableString(row.new_email),
          avatarDraftPath: nullableString(row.avatar_draft_path),
        };
      },
      publishAvatar: async (draftPath) => {
        const extension = fileExtension(draftPath);
        const parts = draftPath.split("/");
        if (parts.length !== 3 || !allowedExtensions.has(extension)) {
          throw new Error("INVALID_AVATAR_DRAFT_PATH");
        }
        const destination = `${parts[0]}/${parts[1]}.${extension}`;
        const { data: blob, error: downloadError } = await service.storage
          .from(requestFilesBucket)
          .download(draftPath);
        if (downloadError || !blob) throw new Error("AVATAR_DOWNLOAD_FAILED");

        const { error: uploadError } = await service.storage
          .from(avatarsBucket)
          .upload(destination, blob, {
            contentType: blob.type || contentTypeFor(extension),
            upsert: true,
          });
        if (uploadError) throw new Error("AVATAR_PUBLISH_FAILED");

        const { data } = service.storage
          .from(avatarsBucket)
          .getPublicUrl(destination);
        return { url: data.publicUrl, objectPath: destination };
      },
      updateAuthEmail: async (userId, email) => {
        const { error } = await service.auth.admin.updateUserById(userId, {
          email,
          email_confirm: true,
        });
        if (error) throw new Error("AUTH_EMAIL_UPDATE_FAILED");
      },
      restoreAuthEmail: async (userId, email) => {
        const { error } = await service.auth.admin.updateUserById(userId, {
          email,
          email_confirm: true,
        });
        if (error) throw new Error("AUTH_EMAIL_RESTORE_FAILED");
      },
      finalize: async (id, avatarUrl) => {
        const { data, error } = await service.rpc(
          "finalize_driver_profile_change_approval",
          {
            p_request_id: id,
            p_admin_id: user.id,
            p_avatar_url: avatarUrl,
          },
        );
        if (error || asRecord(data).status !== "approved") {
          throw new Error("PROFILE_FINALIZE_FAILED");
        }
      },
      rollback: async (id, reason, compensationFailed) => {
        const { error } = await service.rpc(
          "rollback_driver_profile_change_approval",
          {
            p_request_id: id,
            p_admin_id: user.id,
            p_reason: reason,
            p_compensation_failed: compensationFailed,
          },
        );
        if (error) throw new Error("PROFILE_ROLLBACK_FAILED");
      },
      removePublishedAvatar: async (path) => {
        const { error } = await service.storage
          .from(avatarsBucket)
          .remove([path]);
        if (error) throw new Error("PUBLISHED_AVATAR_CLEANUP_FAILED");
      },
      removeAvatarDraft: async (path) => {
        const { error } = await service.storage
          .from(requestFilesBucket)
          .remove([path]);
        if (error) throw new Error("AVATAR_DRAFT_CLEANUP_FAILED");
      },
    });

    return json({ status: result.status, request_id: requestId });
  } catch (error) {
    if (error instanceof ApprovalHttpError) {
      if (error.code === "ALREADY_APPROVED") {
        return json({ status: "approved" }, 200);
      }
      return json({ error: error.code }, error.status);
    }
    console.error("DRIVER_PROFILE_APPROVAL_FAILED");
    return json({ error: "PROFILE_APPROVAL_FAILED" }, 500);
  }
});

async function parseBody(request: Request): Promise<{ request_id?: string }> {
  try {
    const value = await request.json();
    if (!value || typeof value !== "object" || Array.isArray(value)) {
      throw new Error("invalid body");
    }
    const requestId = (value as Record<string, unknown>).request_id;
    return {
      request_id: typeof requestId === "string" ? requestId : undefined,
    };
  } catch {
    throw new ApprovalHttpError("INVALID_JSON_BODY", 400);
  }
}

function asRecord(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("INVALID_RPC_RESULT");
  }
  return value as Record<string, unknown>;
}

function requiredString(value: unknown, code: string): string {
  if (typeof value !== "string" || !value.trim()) throw new Error(code);
  return value;
}

function nullableString(value: unknown): string | null {
  return typeof value === "string" && value.trim() ? value : null;
}

function fileExtension(path: string): string {
  const filename = path.split("/").at(-1) ?? "";
  return filename.includes(".")
    ? (filename.split(".").at(-1) ?? "").toLowerCase()
    : "";
}

function contentTypeFor(extension: string): string {
  if (extension === "png") return "image/png";
  if (extension === "webp") return "image/webp";
  return "image/jpeg";
}

function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing ${name}`);
  return value;
}

function json(value: unknown, status = 200): Response {
  return cors(
    new Response(JSON.stringify(value), {
      status,
      headers: { "Content-Type": "application/json" },
    }),
  );
}

function cors(response: Response): Response {
  const headers = new Headers(response.headers);
  headers.set("Access-Control-Allow-Origin", "*");
  headers.set(
    "Access-Control-Allow-Headers",
    "authorization, apikey, content-type, x-client-info",
  );
  return new Response(response.body, { status: response.status, headers });
}
