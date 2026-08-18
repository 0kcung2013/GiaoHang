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
    const anonKey = requiredEnv("SUPABASE_ANON_KEY");
    const tmnCode = requiredEnv("VNPAY_TMN_CODE");
    const hashSecret = requiredEnv("VNPAY_HASH_SECRET");
    const client = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
    });
    const { data: { user }, error: userError } = await client.auth.getUser();
    if (userError || !user) return json({ error: "AUTH_REQUIRED" }, 401);

    const body = await request.json() as { amount?: unknown };
    const amount = Number(body.amount);
    if (!Number.isSafeInteger(amount) || amount < 5000 || amount > 10000000) {
      return json({ error: "TOPUP_AMOUNT_INVALID" }, 400);
    }

    const txnRef = `W${Date.now()}${crypto.randomUUID().replaceAll("-", "").slice(0, 8)}`;
    const { error: topupError } = await client.rpc(
      "create_driver_wallet_topup",
      { p_amount: amount, p_txn_ref: txnRef },
    );
    if (topupError) throw topupError;

    const now = new Date();
    const expire = new Date(now.getTime() + 15 * 60 * 1000);
    const returnUrl = Deno.env.get("VNPAY_RETURN_URL") ??
      `${supabaseUrl}/functions/v1/vnpay-wallet-return`;
    const forwarded = request.headers.get("x-forwarded-for")?.split(",")[0].trim();
    const params: VnpayParams = {
      vnp_Version: "2.1.0",
      vnp_Command: "pay",
      vnp_TmnCode: tmnCode,
      vnp_Amount: amount * 100,
      vnp_CurrCode: "VND",
      vnp_TxnRef: txnRef,
      vnp_OrderInfo: `Nap vi tai xe ${txnRef}`,
      vnp_OrderType: "other",
      vnp_Locale: "vn",
      vnp_ReturnUrl: returnUrl,
      vnp_IpAddr: forwarded || "127.0.0.1",
      vnp_CreateDate: formatVnpayDate(now),
      vnp_ExpireDate: formatVnpayDate(expire),
    };
    const signature = await signVnpayParams(params, hashSecret);
    return json({
      payment_url: buildVnpayPaymentUrl(paymentUrl, params, signature),
      txn_ref: txnRef,
      expires_at: expire.toISOString(),
    });
  } catch (error) {
    console.error("VNPAY_CREATE_TOPUP_FAILED", safeError(error));
    return json({ error: "TOPUP_CREATE_FAILED" }, 500);
  }
});

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
  headers.set("Access-Control-Allow-Headers", "authorization, apikey, content-type, x-client-info");
  return new Response(response.body, { status: response.status, headers });
}
