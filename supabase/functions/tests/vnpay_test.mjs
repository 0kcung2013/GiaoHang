import assert from 'node:assert/strict';
import test from 'node:test';

import {
  canonicalQuery,
  signVnpayParams,
  verifyVnpaySignature,
} from '../_shared/vnpay.ts';
import {handleVnpayWalletReturn} from '../_shared/vnpay_wallet_return.ts';
import {handleVnpayOrderReturn} from '../_shared/vnpay_order_return.ts';

test('canonical query sorts keys and applies VNPAY form encoding', () => {
  assert.equal(
    canonicalQuery({
      vnp_OrderInfo: 'Nap vi 200000',
      vnp_Amount: '20000000',
    }),
    'vnp_Amount=20000000&vnp_OrderInfo=Nap+vi+200000',
  );
});

test('HMAC-SHA512 signature matches a hand-checked fixture', async () => {
  const params = {
    vnp_OrderInfo: 'Nap vi 200000',
    vnp_Amount: '20000000',
  };
  const signature = await signVnpayParams(params, 'sandbox-secret');

  assert.equal(
    signature,
    '10dd8ccdf528a0ecc37b07c368017c2915e5c27451724066db29efc554e1e64b1fd5e534afd8ad5a0f797419c6fbceec587389887c601e5ae56a8a1048625440',
  );
  assert.equal(
    await verifyVnpaySignature(
      {...params, vnp_SecureHash: signature},
      'sandbox-secret',
    ),
    true,
  );
  assert.equal(
    await verifyVnpaySignature(
      {...params, vnp_Amount: '20000100', vnp_SecureHash: signature},
      'sandbox-secret',
    ),
    false,
  );
});

test('signed successful Return credits the matching pending top-up', async () => {
  const secret = 'sandbox-secret';
  const params = {
    vnp_TmnCode: 'DEMO1234',
    vnp_TxnRef: 'W-demo-1',
    vnp_Amount: '50000000',
    vnp_ResponseCode: '00',
    vnp_TransactionStatus: '00',
    vnp_TransactionNo: 'VNP-123',
  };
  const signature = await signVnpayParams(params, secret);
  const url = new URL('https://merchant.test/vnpay-return');
  for (const [key, value] of Object.entries({
    ...params,
    vnp_SecureHash: signature,
  })) {
    url.searchParams.set(key, value);
  }

  const completions = [];
  const response = await handleVnpayWalletReturn(new Request(url), {
    hashSecret: secret,
    tmnCode: 'DEMO1234',
    findTopup: async () => ({amount: 500000, status: 'pending'}),
    completeTopup: async (input) => completions.push(input),
  });

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    valid: true,
    status: 'success',
    message: 'Thanh toán thành công. Ví đã được cập nhật.',
  });
  assert.deepEqual(completions, [{
    txnRef: 'W-demo-1',
    transactionNo: 'VNP-123',
    responseCode: '00',
  }]);
});


test('signed successful order Return completes the pending Sandbox payment', async () => {
  const secret = 'sandbox-secret';
  const params = {
    vnp_TmnCode: 'DEMO1234',
    vnp_TxnRef: 'O-demo-1',
    vnp_Amount: '2500000',
    vnp_ResponseCode: '00',
    vnp_TransactionStatus: '00',
    vnp_TransactionNo: 'VNP-ORDER-123',
  };
  const signature = await signVnpayParams(params, secret);
  const url = new URL('https://merchant.test/vnpay-order-return');
  for (const [key, value] of Object.entries({...params, vnp_SecureHash: signature})) {
    url.searchParams.set(key, value);
  }

  const completions = [];
  const response = await handleVnpayOrderReturn(new Request(url), {
    hashSecret: secret,
    tmnCode: 'DEMO1234',
    findPayment: async () => ({
      sessionId: 'session-1',
      amount: 25000,
      status: 'pending',
    }),
    completePayment: async (input) => {
      completions.push(input);
      return {status: 'paid'};
    },
  });

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    valid: true,
    status: 'paid',
    session_id: 'session-1',
    message: 'Thanh toán thành công. Đơn hàng đã được tạo.',
  });
  assert.deepEqual(completions, [{
    txnRef: 'O-demo-1',
    transactionNo: 'VNP-ORDER-123',
    responseCode: '00',
  }]);
});

test('order Return rejects a forged callback without completing payment', async () => {
  let completionCount = 0;
  const response = await handleVnpayOrderReturn(
    new Request(
      'https://merchant.test/vnpay-order-return?' +
      'vnp_TmnCode=DEMO1234&vnp_TxnRef=O-demo-2&vnp_Amount=2500000&' +
      'vnp_ResponseCode=00&vnp_TransactionStatus=00&vnp_SecureHash=forged',
    ),
    {
      hashSecret: 'sandbox-secret',
      tmnCode: 'DEMO1234',
      findPayment: async () => ({
        sessionId: 'session-2',
        amount: 25000,
        status: 'pending',
      }),
      completePayment: async () => {
        completionCount += 1;
        return {status: 'paid'};
      },
    },
  );

  assert.equal(response.status, 200);
  assert.equal((await response.json()).status, 'failed');
  assert.equal(completionCount, 0);
});

test('paid browser Return renders a friendly message instead of JSON', async () => {
  const secret = 'sandbox-secret';
  const params = {
    vnp_TmnCode: 'DEMO1234',
    vnp_TxnRef: 'O-demo-3',
    vnp_Amount: '2500000',
    vnp_ResponseCode: '00',
    vnp_TransactionStatus: '00',
  };
  const signature = await signVnpayParams(params, secret);
  const url = new URL('https://merchant.test/vnpay-order-return');
  for (const [key, value] of Object.entries({...params, vnp_SecureHash: signature})) {
    url.searchParams.set(key, value);
  }

  const response = await handleVnpayOrderReturn(
    new Request(url, {headers: {accept: 'text/html'}}),
    {
      hashSecret: secret,
      tmnCode: 'DEMO1234',
      findPayment: async () => ({
        sessionId: 'session-3',
        amount: 25000,
        status: 'paid',
      }),
    },
  );

  assert.match(response.headers.get('content-type'), /^text\/plain/);
  assert.match(await response.text(), /Thanh toán thành công/);
});

test('invalid browser Return also renders a friendly failure message', async () => {
  const response = await handleVnpayOrderReturn(
    new Request(
      'https://merchant.test/vnpay-order-return?vnp_SecureHash=forged',
      {headers: {accept: 'text/html'}},
    ),
    {
      hashSecret: 'sandbox-secret',
      tmnCode: 'DEMO1234',
      findPayment: async () => null,
    },
  );

  assert.match(response.headers.get('content-type'), /^text\/plain/);
  assert.match(await response.text(), /Thanh toán không thành công/);
});
