import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { handleVnpayOrderReturn } from "../_shared/vnpay_order_return.ts";

Deno.serve(async (request) => {
  try {
    const supabase = createClient(
      requiredEnv("SUPABASE_URL"),
      requiredEnv("SUPABASE_SERVICE_ROLE_KEY"),
    );
    const sandboxReturnSettlement =
      (Deno.env.get("VNPAY_ENVIRONMENT") ?? "sandbox") === "sandbox";
    return await handleVnpayOrderReturn(request, {
      hashSecret: requiredEnv("VNPAY_HASH_SECRET"),
      tmnCode: requiredEnv("VNPAY_TMN_CODE"),
      appReturnUrl: Deno.env.get("VNPAY_ORDER_APP_RETURN_URL"),
      findPayment: async (txnRef) => {
        const { data, error } = await supabase
          .from("order_payment_sessions")
          .select("id, amount, status")
          .eq("provider", "vnpay")
          .eq("provider_txn_ref", txnRef)
          .maybeSingle();
        if (error) throw error;
        if (!data) return null;
        return {
          sessionId: String(data.id),
          amount: Number(data.amount),
          status: String(data.status),
        };
      },
      completePayment: sandboxReturnSettlement
        ? async ({ txnRef, transactionNo, responseCode }) => {
          const { data, error } = await supabase.rpc(
            "complete_customer_order_payment",
            {
              p_txn_ref: txnRef,
              p_vnp_transaction_no: transactionNo,
              p_success: true,
              p_response_code: responseCode,
            },
          );
          if (error) throw error;
          const completion = singleRow(data);
          return { status: String(completion.status) };
        }
        : undefined,
    });
  } catch (error) {
    console.error(
      "VNPAY_ORDER_RETURN_FAILED",
      error instanceof Error ? error.message : String(error),
    );
    return new Response(JSON.stringify({ error: "RETURN_PROCESSING_FAILED" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});

function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing ${name}`);
  return value;
}

function singleRow(value: unknown): Record<string, unknown> {
  if (Array.isArray(value) && value.length === 1 && value[0]) {
    return value[0] as Record<string, unknown>;
  }
  if (value && typeof value === "object") {
    return value as Record<string, unknown>;
  }
  throw new Error("PAYMENT_COMPLETION_INVALID");
}
