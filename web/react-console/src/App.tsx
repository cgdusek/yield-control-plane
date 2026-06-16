import {
  Activity,
  AlertTriangle,
  BadgeDollarSign,
  CircleDot,
  Database,
  GitBranch,
  HeartPulse,
  ListChecks,
  RefreshCw,
  ShieldAlert
} from 'lucide-react';
import { useMemo, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api, SweepOrder } from './api/client';

const DEFAULT_ACCOUNT = '11111111-1111-4111-8111-111111111111';

type Tab = 'dashboard' | 'create' | 'order' | 'positions' | 'breaks' | 'health' | 'dev';

export function App() {
  const [tab, setTab] = useState<Tab>('dashboard');
  const [accountId, setAccountId] = useState(DEFAULT_ACCOUNT);
  const [orderId, setOrderId] = useState('');
  const queryClient = useQueryClient();

  const health = useQuery({ queryKey: ['health'], queryFn: api.health, refetchInterval: 5000 });
  const ready = useQuery({ queryKey: ['ready'], queryFn: api.ready, refetchInterval: 5000 });
  const order = useQuery({
    queryKey: ['order', orderId],
    queryFn: () => api.getOrder(orderId),
    enabled: Boolean(orderId),
    refetchInterval: orderId ? 2500 : false
  });
  const positions = useQuery({
    queryKey: ['positions', accountId],
    queryFn: () => api.positions(accountId),
    refetchInterval: 5000
  });
  const breaks = useQuery({
    queryKey: ['breaks'],
    queryFn: api.breaks,
    refetchInterval: 5000
  });

  const latestOrder = order.data;
  const activeCount = positions.data?.length ?? 0;
  const openBreaks = breaks.data?.filter((item) => item.status === 'Open').length ?? 0;

  const createOrder = useMutation({
    mutationFn: (input: { amount: string; productAsset: string; idempotencyKey: string }) =>
      api.createOrder(accountId, input.amount, input.productAsset, input.idempotencyKey),
    onSuccess: (created) => {
      setOrderId(created.order_id);
      setTab('order');
      queryClient.invalidateQueries({ queryKey: ['positions', accountId] });
      queryClient.invalidateQueries({ queryKey: ['breaks'] });
    }
  });

  const createPolicy = useMutation({
    mutationFn: (input: { minimumCashBalance: string; targetProduct: string }) =>
      api.createPolicy(accountId, input.minimumCashBalance, input.targetProduct)
  });

  const setMismatch = useMutation({
    mutationFn: api.setMismatch,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['breaks'] })
  });

  const attemptFiddYield = useMutation({
    mutationFn: () => api.attemptFiddYield(accountId)
  });

  const tabs = useMemo(
    () => [
      ['dashboard', Activity, 'Dashboard'],
      ['create', BadgeDollarSign, 'Create'],
      ['order', GitBranch, 'Order'],
      ['positions', Database, 'Positions'],
      ['breaks', ShieldAlert, 'Breaks'],
      ['health', HeartPulse, 'Health'],
      ['dev', AlertTriangle, 'Dev']
    ] as const,
    []
  );

  return (
    <main className="app-shell">
      <aside className="sidebar">
        <div className="brand">
          <CircleDot size={18} />
          <span>Yield Control Plane</span>
        </div>
        <nav aria-label="Console sections">
          {tabs.map(([key, Icon, label]) => (
            <button
              key={key}
              className={tab === key ? 'nav-item active' : 'nav-item'}
              onClick={() => setTab(key)}
              title={label}
            >
              <Icon size={17} />
              <span>{label}</span>
            </button>
          ))}
        </nav>
      </aside>

      <section className="workspace">
        <header className="topbar">
          <div>
            <h1>Institutional Yield Control Plane</h1>
            <p>
              FIDD is modeled as a payment and stablecoin cash rail. Yield belongs to separate fund
              shares, staking positions, or approved strategies.
            </p>
          </div>
          <div className="account-control">
            <label htmlFor="account">Account</label>
            <input id="account" value={accountId} onChange={(event) => setAccountId(event.target.value)} />
          </div>
        </header>

        {tab === 'dashboard' && (
          <Dashboard
            ready={ready.data?.status ?? 'unknown'}
            activeCount={activeCount}
            openBreaks={openBreaks}
            latestOrder={latestOrder}
            onRefresh={() => {
              queryClient.invalidateQueries();
            }}
          />
        )}
        {tab === 'create' && (
          <CreatePanel
            createPolicy={createPolicy.mutate}
            createOrder={createOrder.mutate}
            policyStatus={createPolicy.status}
            orderStatus={createOrder.status}
            error={createOrder.error?.message ?? createPolicy.error?.message}
          />
        )}
        {tab === 'order' && (
          <OrderPanel orderId={orderId} setOrderId={setOrderId} order={order.data} error={order.error?.message} />
        )}
        {tab === 'positions' && <PositionsPanel positions={positions.data ?? []} />}
        {tab === 'breaks' && <BreaksPanel breaks={breaks.data ?? []} />}
        {tab === 'health' && (
          <HealthPanel health={health.data?.status ?? 'unknown'} ready={ready.data?.status ?? 'unknown'} />
        )}
        {tab === 'dev' && (
          <DevPanel
            setMismatch={(enabled) => setMismatch.mutate(enabled)}
            attemptFiddYield={() => attemptFiddYield.mutate()}
            message={attemptFiddYield.error?.message ?? setMismatch.error?.message}
          />
        )}
      </section>
    </main>
  );
}

function Dashboard({
  ready,
  activeCount,
  openBreaks,
  latestOrder,
  onRefresh
}: {
  ready: string;
  activeCount: number;
  openBreaks: number;
  latestOrder?: SweepOrder;
  onRefresh: () => void;
}) {
  return (
    <div className="grid">
      <section className="metric-row">
        <Metric label="Readiness" value={ready} />
        <Metric label="Positions" value={String(activeCount)} />
        <Metric label="Open breaks" value={String(openBreaks)} />
      </section>
      <section className="panel">
        <div className="panel-heading">
          <h2>Latest order</h2>
          <button className="icon-button" onClick={onRefresh} title="Refresh">
            <RefreshCw size={17} />
          </button>
        </div>
        {latestOrder ? <OrderSummary order={latestOrder} /> : <p className="muted">No order selected.</p>}
      </section>
    </div>
  );
}

function Metric({ label, value }: { label: string; value: string }) {
  return (
    <div className="metric">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

function CreatePanel({
  createPolicy,
  createOrder,
  policyStatus,
  orderStatus,
  error
}: {
  createPolicy: (input: { minimumCashBalance: string; targetProduct: string }) => void;
  createOrder: (input: { amount: string; productAsset: string; idempotencyKey: string }) => void;
  policyStatus: string;
  orderStatus: string;
  error?: string;
}) {
  const [minimumCashBalance, setMinimumCashBalance] = useState('100.00');
  const [targetProduct, setTargetProduct] = useState('FYOXX');
  const [amount, setAmount] = useState('250.00');
  const [idempotencyKey, setIdempotencyKey] = useState(`ui-order-${Date.now()}`);

  return (
    <div className="two-column">
      <form
        className="panel form"
        onSubmit={(event) => {
          event.preventDefault();
          createPolicy({ minimumCashBalance, targetProduct });
        }}
      >
        <h2>Create sweep policy</h2>
        <label>
          Minimum cash balance
          <input value={minimumCashBalance} onChange={(event) => setMinimumCashBalance(event.target.value)} />
        </label>
        <label>
          Target product
          <input value={targetProduct} onChange={(event) => setTargetProduct(event.target.value)} />
        </label>
        <button type="submit">Save policy</button>
        <span className="muted">Status: {policyStatus}</span>
      </form>

      <form
        className="panel form"
        onSubmit={(event) => {
          event.preventDefault();
          createOrder({ amount, productAsset: targetProduct, idempotencyKey });
        }}
      >
        <h2>Create sweep order</h2>
        <label>
          Amount
          <input value={amount} onChange={(event) => setAmount(event.target.value)} />
        </label>
        <label>
          Product asset
          <input value={targetProduct} onChange={(event) => setTargetProduct(event.target.value)} />
        </label>
        <label>
          Idempotency key
          <input value={idempotencyKey} onChange={(event) => setIdempotencyKey(event.target.value)} />
        </label>
        <button type="submit">Create order</button>
        <span className="muted">Status: {orderStatus}</span>
        {error && <strong className="error">{error}</strong>}
      </form>
    </div>
  );
}

function OrderPanel({
  orderId,
  setOrderId,
  order,
  error
}: {
  orderId: string;
  setOrderId: (value: string) => void;
  order?: SweepOrder;
  error?: string;
}) {
  return (
    <section className="panel">
      <div className="panel-heading">
        <h2>Sweep order detail</h2>
        <input
          aria-label="Order id"
          placeholder="Order UUID"
          value={orderId}
          onChange={(event) => setOrderId(event.target.value)}
        />
      </div>
      {error && <strong className="error">{error}</strong>}
      {order ? <OrderSummary order={order} /> : <p className="muted">Create or enter an order UUID.</p>}
    </section>
  );
}

function OrderSummary({ order }: { order: SweepOrder }) {
  return (
    <div className="order-summary">
      <div className="status-line">
        <ListChecks size={18} />
        <strong>{order.status}</strong>
        <span>{order.amount} {order.product_asset}</span>
      </div>
      <ol className="timeline">
        {order.timeline.map((entry) => (
          <li key={`${entry.command}-${entry.occurred_at}`}>
            <span>{entry.command}</span>
            <strong>{entry.to_status}</strong>
            <time>{new Date(entry.occurred_at).toLocaleTimeString()}</time>
          </li>
        ))}
      </ol>
    </div>
  );
}

function PositionsPanel({ positions }: { positions: Array<{ position_id: string; product_asset: string; quantity: string; transfer_agent_confirmation_ref: string }> }) {
  return (
    <section className="panel">
      <h2>Positions</h2>
      <div className="table">
        <div className="table-row table-head">
          <span>Product</span>
          <span>Quantity</span>
          <span>Confirmation</span>
        </div>
        {positions.map((position) => (
          <div className="table-row" key={position.position_id}>
            <span>{position.product_asset}</span>
            <span>{position.quantity}</span>
            <span>{position.transfer_agent_confirmation_ref}</span>
          </div>
        ))}
      </div>
    </section>
  );
}

function BreaksPanel({ breaks }: { breaks: Array<{ break_id: string; order_id: string; reason: string; status: string }> }) {
  return (
    <section className="panel">
      <h2>Reconciliation breaks</h2>
      <div className="table">
        <div className="table-row table-head">
          <span>Status</span>
          <span>Order</span>
          <span>Reason</span>
        </div>
        {breaks.map((item) => (
          <div className="table-row" key={item.break_id}>
            <span>{item.status}</span>
            <span>{item.order_id}</span>
            <span>{item.reason}</span>
          </div>
        ))}
      </div>
    </section>
  );
}

function HealthPanel({ health, ready }: { health: string; ready: string }) {
  return (
    <section className="metric-row">
      <Metric label="Health" value={health} />
      <Metric label="Ready" value={ready} />
    </section>
  );
}

function DevPanel({
  setMismatch,
  attemptFiddYield,
  message
}: {
  setMismatch: (enabled: boolean) => void;
  attemptFiddYield: () => void;
  message?: string;
}) {
  return (
    <section className="panel form">
      <h2>Local failure controls</h2>
      <div className="button-row">
        <button onClick={() => setMismatch(true)}>Enable mismatch</button>
        <button onClick={() => setMismatch(false)}>Disable mismatch</button>
        <button onClick={attemptFiddYield}>Attempt FIDD yield</button>
      </div>
      <p className="muted">Transfer-agent confirmation is authoritative for this local FYOXX-style flow.</p>
      {message && <strong className="error">{message}</strong>}
    </section>
  );
}
