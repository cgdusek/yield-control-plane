export type SweepOrder = {
  order_id: string;
  account_id: string;
  status: string;
  amount: string;
  cash_asset: string;
  product_asset: string;
  transfer_agent_confirmation_ref: string | null;
  timeline: TimelineEntry[];
};

export type TimelineEntry = {
  from_status: string | null;
  to_status: string;
  command: string;
  occurred_at: string;
};

export type Position = {
  position_id: string;
  account_id: string;
  order_id: string;
  product_asset: string;
  quantity: string;
  transfer_agent_confirmation_ref: string;
};

export type ReconciliationBreak = {
  break_id: string;
  order_id: string;
  reason: string;
  status: string;
  created_at: string;
};

export type HealthResponse = {
  status: string;
  service: string;
};

const API_BASE = import.meta.env.VITE_API_BASE_URL ?? '/api';

function headers(idempotencyKey?: string): HeadersInit {
  const output: Record<string, string> = {
    'Content-Type': 'application/json'
  };
  if (idempotencyKey) {
    output['Idempotency-Key'] = idempotencyKey;
    output['Correlation-Id'] = `ui-${Date.now()}`;
  }
  return output;
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(`${API_BASE}${path}`, init);
  if (!response.ok) {
    const body = await response.json().catch(() => ({ message: response.statusText }));
    throw new Error(body.message ?? response.statusText);
  }
  return (await response.json()) as T;
}

export const api = {
  health: () => request<HealthResponse>('/health'),
  ready: () => request<HealthResponse>('/ready'),
  createPolicy: (accountId: string, minimumCashBalance: string, targetProduct: string) =>
    request('/sweep-policies', {
      method: 'POST',
      headers: headers(`policy-${accountId}`),
      body: JSON.stringify({
        account_id: accountId,
        minimum_cash_balance: minimumCashBalance,
        target_product: targetProduct
      })
    }),
  createOrder: (
    accountId: string,
    amount: string,
    productAsset: string,
    idempotencyKey: string
  ) =>
    request<SweepOrder>('/sweep-orders', {
      method: 'POST',
      headers: headers(idempotencyKey),
      body: JSON.stringify({
        account_id: accountId,
        amount,
        cash_asset: 'USD',
        product_asset: productAsset
      })
    }),
  getOrder: (orderId: string) => request<SweepOrder>(`/sweep-orders/${orderId}`),
  positions: (accountId: string) => request<Position[]>(`/accounts/${accountId}/positions`),
  breaks: () => request<ReconciliationBreak[]>('/reconciliation-breaks'),
  setMismatch: (enabled: boolean) =>
    request('/dev/failure-injections/reconciliation-mismatch', {
      method: 'POST',
      headers: headers(`mismatch-${enabled}-${Date.now()}`),
      body: JSON.stringify({ enabled })
    }),
  attemptFiddYield: (accountId: string) =>
    request('/dev/attempt-fidd-yield', {
      method: 'POST',
      headers: headers(`fidd-yield-${Date.now()}`),
      body: JSON.stringify({ account_id: accountId, amount: '1.00' })
    })
};
