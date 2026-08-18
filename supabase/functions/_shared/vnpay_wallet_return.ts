import {
  verifyVnpaySignature,
  type VnpayParams,
} from './vnpay.ts';

export type WalletTopupSnapshot = {
  amount: number;
  status: string;
};

export type CompleteWalletTopupInput = {
  txnRef: string;
  transactionNo: string;
  responseCode: string;
};

export type VnpayWalletReturnDependencies = {
  hashSecret: string;
  tmnCode: string;
  appReturnUrl?: string;
  findTopup: (txnRef: string) => Promise<WalletTopupSnapshot | null>;
  completeTopup: (input: CompleteWalletTopupInput) => Promise<unknown>;
};

export async function handleVnpayWalletReturn(
  request: Request,
  dependencies: VnpayWalletReturnDependencies,
): Promise<Response> {
  if (request.method !== 'GET') {
    return json({error: 'METHOD_NOT_ALLOWED'}, 405);
  }

  const params = Object.fromEntries(
    new URL(request.url).searchParams,
  ) as VnpayParams;
  const signatureValid = await verifyVnpaySignature(
    params,
    dependencies.hashSecret,
  );
  const terminalValid = params.vnp_TmnCode === dependencies.tmnCode;
  const txnRef = String(params.vnp_TxnRef ?? '');
  const topup = txnRef ? await dependencies.findTopup(txnRef) : null;
  const amountValid = topup != null &&
    Number(params.vnp_Amount) === topup.amount * 100;
  const valid = signatureValid && terminalValid && amountValid;
  const paymentSuccessful = params.vnp_ResponseCode === '00' &&
    params.vnp_TransactionStatus === '00';
  const canComplete = valid && paymentSuccessful &&
    topup?.status === 'pending';

  if (canComplete) {
    await dependencies.completeTopup({
      txnRef,
      transactionNo: String(params.vnp_TransactionNo ?? ''),
      responseCode: String(params.vnp_ResponseCode ?? ''),
    });
  }

  const success = valid && paymentSuccessful &&
    (topup?.status === 'pending' || topup?.status === 'completed');
  const status = success ? 'success' : 'failed';
  const message = success
    ? 'Thanh toán thành công. Ví đã được cập nhật.'
    : 'Giao dịch không thành công.';

  if (dependencies.appReturnUrl) {
    const target = new URL(dependencies.appReturnUrl);
    target.searchParams.set('status', status);
    target.searchParams.set('txn_ref', txnRef);
    return Response.redirect(target, 302);
  }

  return json({valid, status, message});
}

function json(value: unknown, status = 200): Response {
  return new Response(JSON.stringify(value), {
    status,
    headers: {'Content-Type': 'application/json'},
  });
}
