import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { handleVnpayWalletReturn } from "../_shared/vnpay_wallet_return.ts";

Deno.serve(async (request) => {
  try {
    const supabase = createClient(
      requiredEnv("SUPABASE_URL"),
      requiredEnv("SUPABASE_SERVICE_ROLE_KEY"),
    );
    return await handleVnpayWalletReturn(request, {
      hashSecret: requiredEnv("VNPAY_HASH_SECRET"),
      tmnCode: requiredEnv("VNPAY_TMN_CODE"),
      appReturnUrl: Deno.env.get("VNPAY_APP_RETURN_URL"),
      findTopup: async (txnRef) => {
        const { data, error } = await supabase
          .from("driver_wallet_transactions")
          .select("amount, status")
          .eq("provider", "vnpay")
          .eq("provider_txn_ref", txnRef)
          .maybeSingle();
        if (error) throw error;
        return data;
      },
      completeTopup: async (input) => {
        const { error } = await supabase.rpc(
          "complete_driver_wallet_topup",
          {
            p_txn_ref: input.txnRef,
            p_vnp_transaction_no: input.transactionNo,
            p_success: true,
            p_response_code: input.responseCode,
          },
        );
        if (error) throw error;
      },
    });
  } catch (error) {
    console.error(
      "VNPAY_RETURN_FAILED",
      error instanceof Error ? error.message : String(error),
    );
    return json({ error: "RETURN_PROCESSING_FAILED" }, 500);
  }
});

function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing ${name}`);
  return value;
}

function json(value: unknown, status = 200): Response {
  return new Response(JSON.stringify(value), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
