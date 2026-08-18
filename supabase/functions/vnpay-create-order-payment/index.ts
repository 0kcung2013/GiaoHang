import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import {
  buildVnpayPaymentUrl,
  formatVnpayDate,
  signVnpayParams,
  type VnpayParams,
} from "../_shared/vnpay.ts";

const paymentUrl = "https://sandbox.vnpayment.vn/paymentv2/vpcpay.html";

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return cors(new Response(null));
  if (request.method !== "POST") return json({ error: "METHOD_NOT_ALLOWED" }, 405);

  try {
    const authorization = request.headers.get("Authorization");
    if (!authorization) return json({ error: "AUTH_REQUIRED" }, 401);

    const supabaseUrl = requiredEnv("SUPABASE_URL");
    const authClient = createClient(supabaseUrl, requiredEnv("SUPABASE_ANON_KEY"), {
      global: { headers: { Authorization: authorization } },
    });
    const { data: { user }, error: userError } = await authClient.auth.getUser();
    if (userError || !user) return json({ error: "AUTH_REQUIRED" }, 401);

    const orderPayload = await request.json() as Record<string, unknown>;
    const txnRef = `O${Date.now()}${crypto.randomUUID().replaceAll("-", "").slice(0, 8)}`;
    const serviceClient = createClient(
      supabaseUrl,
      requiredEnv("SUPABASE_SERVICE_ROLE_KEY"),
    );
    const { data, error } = await serviceClient.rpc(
      "create_customer_order_payment_session",
      {
        p_customer_id: user.id,
        p_order_payload: orderPayload,
        p_txn_ref: txnRef,
      },
    );
    if (error) throw error;
    const session = singleRow(data);
    const amount = Number(session.amount);
    if (!Number.isSafeInteger(amount)) throw new Error("PAYMENT_AMOUNT_INVALID");

    const now = new Date();
    const expiresAt = new Date(String(session.expires_at));
    if (Number.isNaN(expiresAt.getTime())) throw new Error("PAYMENT_EXPIRY_INVALID");
    const returnUrl = Deno.env.get("VNPAY_ORDER_RETURN_URL") ??
      `${supabaseUrl}/functions/v1/vnpay-order-return`;
    const forwarded = request.headers.get("x-forwarded-for")?.split(",")[0].trim();
    const params: VnpayParams = {
      vnp_Version: "2.1.0",
      vnp_Command: "pay",
      vnp_TmnCode: requiredEnv("VNPAY_TMN_CODE"),
      vnp_Amount: amount * 100,
      vnp_CurrCode: "VND",
      vnp_TxnRef: txnRef,
      vnp_OrderInfo: `Thanh toan phi giao hang ${txnRef}`,
      vnp_OrderType: "other",
      vnp_Locale: "vn",
      vnp_ReturnUrl: returnUrl,
      vnp_IpAddr: forwarded || "127.0.0.1",
      vnp_CreateDate: formatVnpayDate(now),
      vnp_ExpireDate: formatVnpayDate(expiresAt),
    };
    const signature = await signVnpayParams(
      params,
      requiredEnv("VNPAY_HASH_SECRET"),
    );

    return json({
      session_id: String(session.session_id),
      txn_ref: txnRef,
      amount,
      status: String(session.status),
      expires_at: expiresAt.toISOString(),
      payment_url: buildVnpayPaymentUrl(paymentUrl, params, signature),
    });
  } catch (error) {
    console.error("VNPAY_CREATE_ORDER_PAYMENT_FAILED", safeError(error));
    return json({ error: "ORDER_PAYMENT_CREATE_FAILED" }, 500);
  }
});

function singleRow(value: unknown): Record<string, unknown> {
  if (Array.isArray(value) && value.length === 1 && value[0]) {
    return value[0] as Record<string, unknown>;
  }
  if (value && typeof value === "object") return value as Record<string, unknown>;
  throw new Error("PAYMENT_SESSION_INVALID");
}

function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing ${name}`);
  return value;
}

function safeError(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

function json(value: unknown, status = 200): Response {
  return cors(new Response(JSON.stringify(value), {
    status,
    headers: { "Content-Type": "application/json" },
  }));
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
