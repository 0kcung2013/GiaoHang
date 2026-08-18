import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { verifyVnpaySignature, type VnpayParams } from "../_shared/vnpay.ts";

Deno.serve(async (request) => {
  if (request.method !== "GET") return reply("99", "Invalid request");
  try {
    const params = Object.fromEntries(new URL(request.url).searchParams) as VnpayParams;
    const secret = requiredEnv("VNPAY_HASH_SECRET");
    if (!await verifyVnpaySignature(params, secret)) {
      return reply("97", "Invalid signature");
    }
    if (params.vnp_TmnCode !== requiredEnv("VNPAY_TMN_CODE")) {
      return reply("97", "Invalid terminal");
    }

    const supabase = createClient(
      requiredEnv("SUPABASE_URL"),
      requiredEnv("SUPABASE_SERVICE_ROLE_KEY"),
    );
    const txnRef = String(params.vnp_TxnRef ?? "");
    if (txnRef.startsWith("O")) {
      const { data: payment, error: lookupError } = await supabase
        .from("order_payment_sessions")
        .select("id, amount, status")
        .eq("provider", "vnpay")
        .eq("provider_txn_ref", txnRef)
        .maybeSingle();
      if (lookupError || !payment) return reply("01", "Order not found");
      if (Number(params.vnp_Amount) !== Number(payment.amount) * 100) {
        return reply("04", "Invalid amount");
      }
      if (payment.status === "paid") return reply("00", "Confirm Success");

      const success = params.vnp_ResponseCode === "00" &&
        params.vnp_TransactionStatus === "00";
      const { error: completeError } = await supabase.rpc(
        "complete_customer_order_payment",
        {
          p_txn_ref: txnRef,
          p_vnp_transaction_no: String(params.vnp_TransactionNo ?? ""),
          p_success: success,
          p_response_code: String(params.vnp_ResponseCode ?? ""),
        },
      );
      if (completeError) throw completeError;
      return reply("00", "Confirm Success");
    }

    const { data: topup, error: lookupError } = await supabase
      .from("driver_wallet_transactions")
      .select("id, amount, status")
      .eq("provider", "vnpay")
      .eq("provider_txn_ref", txnRef)
      .maybeSingle();
    if (lookupError || !topup) return reply("01", "Order not found");
    if (Number(params.vnp_Amount) !== Number(topup.amount) * 100) {
      return reply("04", "Invalid amount");
    }
    if (topup.status === "completed") return reply("00", "Confirm Success");

    const success = params.vnp_ResponseCode === "00" &&
      params.vnp_TransactionStatus === "00";
    const { error: completeError } = await supabase.rpc(
      "complete_driver_wallet_topup",
      {
        p_txn_ref: txnRef,
        p_vnp_transaction_no: String(params.vnp_TransactionNo ?? ""),
        p_success: success,
        p_response_code: String(params.vnp_ResponseCode ?? ""),
      },
    );
    if (completeError) throw completeError;
    return reply("00", "Confirm Success");
  } catch (error) {
    console.error("VNPAY_IPN_FAILED", error instanceof Error ? error.message : String(error));
    return reply("99", "Unknown error");
  }
});

function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing ${name}`);
  return value;
}
function reply(code: string, message: string): Response {
  return new Response(JSON.stringify({ RspCode: code, Message: message }), {
    headers: { "Content-Type": "application/json" },
  });
}
