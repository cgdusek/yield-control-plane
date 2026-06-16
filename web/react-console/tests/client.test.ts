import { api } from '../src/api/client';

test('createOrder sends idempotency and correlation headers', async () => {
  const calls: Array<{ input: RequestInfo | URL; init?: RequestInit }> = [];
  const originalFetch = globalThis.fetch;
  globalThis.fetch = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
    calls.push({ input, init });
    return new Response(
      JSON.stringify({
        order_id: '11111111-1111-4111-8111-111111111111',
        account_id: '11111111-1111-4111-8111-111111111111',
        status: 'Created',
        amount: '10.00',
        cash_asset: 'USD',
        product_asset: 'FYOXX',
        transfer_agent_confirmation_ref: null,
        timeline: []
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    );
  }) as typeof fetch;

  await api.createOrder('11111111-1111-4111-8111-111111111111', '10.00', 'FYOXX', 'key-1');
  const headers = calls[0].init?.headers as Record<string, string>;
  expect(headers['Idempotency-Key']).toBe('key-1');
  expect(headers['Correlation-Id']).toMatch(/^ui-/);
  globalThis.fetch = originalFetch;
});
