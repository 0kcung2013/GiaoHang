import { verifyVnpaySignature, type VnpayParams } from "./vnpay.ts";

export type OrderPaymentSnapshot = {
  sessionId: string;
  amount: number;
  status: string;
};

export type CompleteOrderPaymentInput = {
  txnRef: string;
  transactionNo: string;
  responseCode: string;
};

export type OrderPaymentCompletion = {
  status: string;
};

export type VnpayOrderReturnDependencies = {
  hashSecret: string;
  tmnCode: string;
  appReturnUrl?: string;
  findPayment: (txnRef: string) => Promise<OrderPaymentSnapshot | null>;
  completePayment?: (
    input: CompleteOrderPaymentInput,
  ) => Promise<OrderPaymentCompletion>;
};

export async function handleVnpayOrderReturn(
  request: Request,
  dependencies: VnpayOrderReturnDependencies,
): Promise<Response> {
  if (request.method !== "GET") return json({ error: "METHOD_NOT_ALLOWED" }, 405);

  const params = Object.fromEntries(new URL(request.url).searchParams) as VnpayParams;
  const txnRef = String(params.vnp_TxnRef ?? "");
  const signatureValid = await verifyVnpaySignature(params, dependencies.hashSecret);
  const terminalValid = params.vnp_TmnCode === dependencies.tmnCode;
  if (!signatureValid || !terminalValid) {
    return resultResponse({
      dependencies,
      txnRef,
      status: "failed",
      sessionId: null,
      valid: false,
      prefersHtml: request.headers.get("accept")?.includes("text/html") ?? false,
    });
  }

  const payment = txnRef ? await dependencies.findPayment(txnRef) : null;
  const amountValid = payment != null &&
    Number(params.vnp_Amount) === payment.amount * 100;
  const callbackSuccessful = params.vnp_ResponseCode === "00" &&
    params.vnp_TransactionStatus === "00";
  const valid = signatureValid && terminalValid && amountValid;
  let paymentStatus = payment?.status ?? "failed";
  const canComplete = valid && callbackSuccessful &&
    paymentStatus === "pending" && dependencies.completePayment != null;
  if (canComplete) {
    const completion = await dependencies.completePayment!({
      txnRef,
      transactionNo: String(params.vnp_TransactionNo ?? ""),
      responseCode: String(params.vnp_ResponseCode ?? ""),
    });
    paymentStatus = completion.status;
  }

  const status = !valid || !callbackSuccessful
    ? "failed"
    : paymentStatus === "paid"
    ? "paid"
    : paymentStatus === "pending"
    ? "pending"
    : paymentStatus;

  return resultResponse({
    dependencies,
    txnRef,
    status,
    sessionId: payment?.sessionId ?? null,
    valid,
    prefersHtml: request.headers.get("accept")?.includes("text/html") ?? false,
  });
}

function resultResponse({
  dependencies,
  txnRef,
  status,
  sessionId,
  valid,
  prefersHtml,
}: {
  dependencies: VnpayOrderReturnDependencies;
  txnRef: string;
  status: string;
  sessionId: string | null;
  valid: boolean;
  prefersHtml: boolean;
}): Response {
  if (dependencies.appReturnUrl) {
    const target = new URL(dependencies.appReturnUrl);
    target.searchParams.set("payment_status", status);
    target.searchParams.set("session_id", sessionId ?? "");
    target.searchParams.set("txn_ref", txnRef);
    return Response.redirect(target, 302);
  }

  if (prefersHtml) return browserResult(status);

  return json({
    valid,
    status,
    session_id: sessionId,
    message: status === "paid"
      ? "Thanh toán thành công. Đơn hàng đã được tạo."
      : status === "pending"
      ? "Thanh toán đang được xác nhận. Vui lòng quay lại ứng dụng."
      : "Giao dịch không thành công.",
  });
}

function browserResult(status: string): Response {
  const paid = status === "paid";
  const pending = status === "pending";
  const title = paid
    ? "Thanh toán thành công"
    : pending
    ? "Đang xác nhận thanh toán"
    : "Thanh toán không thành công";
  const message = paid
    ? "Đơn hàng đã được tạo. Bạn có thể quay lại ứng dụng."
    : pending
    ? "Hệ thống đang xác nhận giao dịch. Vui lòng quay lại ứng dụng để kiểm tra."
    : "Giao dịch chưa hoàn tất. Vui lòng quay lại ứng dụng và thử lại.";
  return new Response(
    `${title}\n\n${message}\n\nBạn có thể đóng trang này.`,
    {
    headers: {
      "Content-Type": "text/plain; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
}

function json(value: unknown, status = 200): Response {
  return new Response(JSON.stringify(value), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
