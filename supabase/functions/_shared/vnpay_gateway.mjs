const sandboxUrl = 'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html';

/** Fail closed when production has not been configured by the merchant. */
export function resolveVnpayPaymentUrl(environment = 'sandbox', configuredUrl) {
  if (!['sandbox', 'production'].includes(environment)) {
    throw new Error('VNPAY_ENVIRONMENT_INVALID');
  }
  if (environment === 'production' && !configuredUrl?.trim()) {
    throw new Error('VNPAY_PAYMENT_URL_REQUIRED');
  }
  const url = new URL(configuredUrl?.trim() || sandboxUrl);
  const approvedHost = url.hostname === 'vnpay.vn' || url.hostname.endsWith('.vnpay.vn') ||
    url.hostname === 'vnpayment.vn' || url.hostname.endsWith('.vnpayment.vn');
  if (url.protocol !== 'https:' || url.username || url.password || url.port ||
      url.search || url.hash || !approvedHost) throw new Error('VNPAY_PAYMENT_URL_INVALID');
  const sandbox = url.hostname === 'sandbox.vnpayment.vn';
  if ((environment === 'sandbox') !== sandbox) {
    throw new Error('VNPAY_GATEWAY_ENVIRONMENT_MISMATCH');
  }
  return url.toString();
}
