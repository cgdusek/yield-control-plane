create table if not exists accounts (
  account_id uuid primary key,
  display_name text not null default 'Local demo account',
  created_at timestamptz not null default now()
);

create table if not exists sweep_policies (
  account_id uuid primary key references accounts(account_id),
  minimum_cash_balance numeric(38, 12) not null check (minimum_cash_balance >= 0),
  target_product text not null,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists sweep_orders (
  order_id uuid primary key,
  account_id uuid not null references accounts(account_id),
  idempotency_key_hash text not null,
  correlation_id text not null,
  status text not null check (status in (
    'Created',
    'EligibilityChecked',
    'DisclosureChecked',
    'Approved',
    'CashLocked',
    'SubscriptionSubmitted',
    'TransferAgentConfirmed',
    'ChainMirrorObserved',
    'PositionBooked',
    'Reconciled',
    'Active',
    'RedemptionRequested',
    'SharesReserved',
    'RedemptionSubmitted',
    'RedemptionConfirmed',
    'CashCredited',
    'Settled',
    'ExceptionOpen',
    'ExceptionClosed',
    'Cancelled'
  )),
  amount numeric(38, 12) not null check (amount > 0),
  cash_asset text not null check (cash_asset in ('USD', 'FIDD')),
  product_asset text not null,
  external_order_ref text,
  transfer_agent_confirmation_ref text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (account_id, idempotency_key_hash),
  unique (external_order_ref),
  unique (transfer_agent_confirmation_ref)
);

create table if not exists state_transitions (
  transition_id uuid primary key,
  order_id uuid not null references sweep_orders(order_id),
  from_status text,
  to_status text not null,
  command text not null,
  emitted_events jsonb not null default '[]'::jsonb,
  guard_results jsonb not null default '[]'::jsonb,
  correlation_id text not null,
  created_at timestamptz not null default now()
);

create table if not exists ledger_entries (
  entry_id uuid primary key,
  account_id uuid not null references accounts(account_id),
  order_id uuid references sweep_orders(order_id),
  asset text not null,
  amount numeric(38, 12) not null check (amount >= 0),
  debit_credit text not null check (debit_credit in ('Debit', 'Credit')),
  ledger_account text not null,
  entry_kind text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create or replace function prevent_ledger_entry_mutation()
returns trigger
language plpgsql
as $$
begin
  raise exception 'ledger_entries are append-only';
end;
$$;

drop trigger if exists ledger_entries_no_update on ledger_entries;
create trigger ledger_entries_no_update
before update or delete on ledger_entries
for each row execute function prevent_ledger_entry_mutation();

create table if not exists positions (
  position_id uuid primary key,
  account_id uuid not null references accounts(account_id),
  order_id uuid not null references sweep_orders(order_id),
  product_asset text not null,
  quantity numeric(38, 12) not null check (quantity > 0),
  transfer_agent_confirmation_ref text not null unique,
  created_at timestamptz not null default now(),
  unique (order_id)
);

create table if not exists reconciliation_breaks (
  break_id uuid primary key,
  order_id uuid not null references sweep_orders(order_id),
  reason text not null,
  status text not null check (status in ('Open', 'Resolved')),
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

create table if not exists outbox_events (
  event_id uuid primary key,
  event_type text not null,
  aggregate_id uuid not null,
  correlation_id text not null,
  causation_id uuid,
  payload jsonb not null,
  status text not null default 'pending' check (status in ('pending', 'leased', 'published', 'failed')),
  attempts integer not null default 0 check (attempts >= 0),
  leased_until timestamptz,
  published_at timestamptz,
  last_error text,
  created_at timestamptz not null default now()
);

create index if not exists outbox_events_pending_idx
  on outbox_events (status, created_at)
  where status in ('pending', 'failed');

create table if not exists inbox_messages (
  consumer text not null,
  message_id text not null,
  event_id uuid not null,
  processed_at timestamptz not null default now(),
  primary key (consumer, message_id)
);

create table if not exists audit_events (
  event_id uuid primary key,
  aggregate_id uuid not null,
  event_type text not null,
  correlation_id text not null,
  payload jsonb not null,
  created_at timestamptz not null default now()
);

create table if not exists idempotency_records (
  scope text not null,
  key_hash text not null,
  request_hash text not null,
  response_json jsonb not null,
  resource_id uuid,
  created_at timestamptz not null default now(),
  primary key (scope, key_hash)
);

create table if not exists failure_injections (
  key text primary key,
  value text not null,
  updated_at timestamptz not null default now()
);
