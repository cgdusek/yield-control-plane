use crate::{
    idempotency::{hash_idempotency_key, hash_request_body},
    outbox::insert_outbox_event,
    CommandInput, CreateSweepOrderInput, CreateSweepPolicyInput, PersistenceError,
    PersistenceResult, PositionRecord, ReconciliationBreakRecord, SweepOrderRecord, SweepOrderRow,
    SweepPolicyRecord, TimelineEntryRecord,
};
use institutional_yield_domain::{
    invariants::ensure_yield_source_allowed, ledger::validate_position_booking_confirmation,
    transition, Asset, DebitCredit, DomainEvent, EventEnvelope, GuardContext, LedgerEntry,
    LedgerEntryKind, SweepCommand, SweepStatus,
};
use rust_decimal::Decimal;
use serde_json::{json, Value};
use sqlx::{PgPool, Postgres, Transaction};
use std::str::FromStr;
use uuid::Uuid;

pub async fn create_sweep_policy(
    pool: &PgPool,
    input: CreateSweepPolicyInput,
) -> PersistenceResult<SweepPolicyRecord> {
    let key_hash = hash_idempotency_key(&input.idempotency_key);
    let request_hash = hash_request_body(
        serde_json::to_vec(&json!({
            "account_id": input.account_id,
            "minimum_cash_balance": input.minimum_cash_balance.to_string(),
            "target_product": &input.target_product,
        }))?
        .as_slice(),
    );
    let scope = format!("sweep-policy:{}", input.account_id);
    let mut tx = pool.begin().await?;
    if let Some(resource_id) =
        existing_idempotent_resource(&mut tx, &scope, &key_hash, &request_hash).await?
    {
        tx.commit().await?;
        return get_sweep_policy(pool, resource_id).await;
    }

    ensure_account(&mut tx, input.account_id).await?;
    let policy = sqlx::query_as::<_, SweepPolicyRecord>(
        r#"
        insert into sweep_policies
          (account_id, minimum_cash_balance, target_product, enabled)
        values ($1, $2, $3, true)
        on conflict (account_id) do update
        set minimum_cash_balance = excluded.minimum_cash_balance,
            target_product = excluded.target_product,
            enabled = true,
            updated_at = now()
        returning account_id, minimum_cash_balance, target_product, enabled, created_at, updated_at
        "#,
    )
    .bind(input.account_id)
    .bind(input.minimum_cash_balance)
    .bind(&input.target_product)
    .fetch_one(&mut *tx)
    .await?;

    record_idempotency(
        &mut tx,
        &scope,
        &key_hash,
        &request_hash,
        Some(policy.account_id),
        json!({"account_id": policy.account_id}),
    )
    .await?;
    tx.commit().await?;
    Ok(policy)
}

pub async fn get_sweep_policy(
    pool: &PgPool,
    account_id: Uuid,
) -> PersistenceResult<SweepPolicyRecord> {
    sqlx::query_as::<_, SweepPolicyRecord>(
        r#"
        select account_id, minimum_cash_balance, target_product, enabled, created_at, updated_at
        from sweep_policies
        where account_id = $1
        "#,
    )
    .bind(account_id)
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| PersistenceError::NotFound(format!("sweep policy {account_id}")))
}

pub async fn create_sweep_order(
    pool: &PgPool,
    input: CreateSweepOrderInput,
) -> PersistenceResult<SweepOrderRecord> {
    let cash_asset = Asset::from_str(&input.cash_asset)?;
    let product_asset = Asset::from_str(&input.product_asset)?;
    ensure_yield_source_allowed(&product_asset)?;
    if !cash_asset.is_cash_rail() {
        return Err(PersistenceError::Parse(format!(
            "cash asset {} is not a supported cash rail",
            cash_asset
        )));
    }

    let key_hash = hash_idempotency_key(&input.idempotency_key);
    let request_hash = hash_request_body(
        serde_json::to_vec(&json!({
            "account_id": input.account_id,
            "amount": input.amount.to_string(),
            "cash_asset": cash_asset.to_string(),
            "product_asset": product_asset.to_string(),
        }))?
        .as_slice(),
    );
    let scope = format!("sweep-order:{}", input.account_id);
    let mut tx = pool.begin().await?;
    if let Some(order_id) =
        existing_idempotent_resource(&mut tx, &scope, &key_hash, &request_hash).await?
    {
        tx.commit().await?;
        return get_sweep_order(pool, order_id).await;
    }

    ensure_account(&mut tx, input.account_id).await?;
    let order_id = Uuid::new_v4();
    sqlx::query(
        r#"
        insert into sweep_orders
          (order_id, account_id, idempotency_key_hash, correlation_id, status, amount, cash_asset, product_asset)
        values ($1, $2, $3, $4, 'Created', $5, $6, $7)
        "#,
    )
    .bind(order_id)
    .bind(input.account_id)
    .bind(&key_hash)
    .bind(&input.correlation_id)
    .bind(input.amount)
    .bind(cash_asset.to_string())
    .bind(product_asset.to_string())
    .execute(&mut *tx)
    .await?;

    insert_transition(
        &mut tx,
        TransitionInsert {
            order_id,
            from_status: None,
            to_status: SweepStatus::Created.as_str(),
            command: "CreateSweepOrder",
            emitted_events: json!(["sweep.order.created.v1"]),
            guard_results: json!([]),
            correlation_id: &input.correlation_id,
        },
    )
    .await?;

    let envelope = EventEnvelope::new(
        DomainEvent::SweepOrderCreated,
        order_id,
        input.correlation_id.clone(),
        None,
        Some(key_hash.clone()),
        json!({
            "order_id": order_id,
            "account_id": input.account_id,
            "amount": input.amount.to_string(),
            "cash_asset": cash_asset.to_string(),
            "product_asset": product_asset.to_string()
        }),
    );
    insert_event_records(&mut tx, &envelope).await?;
    record_idempotency(
        &mut tx,
        &scope,
        &key_hash,
        &request_hash,
        Some(order_id),
        json!({"order_id": order_id}),
    )
    .await?;
    tx.commit().await?;
    get_sweep_order(pool, order_id).await
}

pub async fn get_sweep_order(pool: &PgPool, order_id: Uuid) -> PersistenceResult<SweepOrderRecord> {
    let row = sqlx::query_as::<_, SweepOrderRow>(
        r#"
        select order_id, account_id, idempotency_key_hash, correlation_id, status, amount,
          cash_asset, product_asset, external_order_ref, transfer_agent_confirmation_ref,
          created_at, updated_at
        from sweep_orders
        where order_id = $1
        "#,
    )
    .bind(order_id)
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| PersistenceError::NotFound(format!("sweep order {order_id}")))?;
    let timeline = list_timeline(pool, order_id).await?;
    Ok(SweepOrderRecord {
        order_id: row.order_id,
        account_id: row.account_id,
        status: row.status,
        amount: row.amount,
        cash_asset: row.cash_asset,
        product_asset: row.product_asset,
        external_order_ref: row.external_order_ref,
        transfer_agent_confirmation_ref: row.transfer_agent_confirmation_ref,
        created_at: row.created_at,
        updated_at: row.updated_at,
        timeline,
    })
}

pub async fn list_timeline(
    pool: &PgPool,
    order_id: Uuid,
) -> PersistenceResult<Vec<TimelineEntryRecord>> {
    Ok(sqlx::query_as::<_, TimelineEntryRecord>(
        r#"
        select transition_id, order_id, from_status, to_status, command, correlation_id, created_at
        from state_transitions
        where order_id = $1
        order by created_at asc
        "#,
    )
    .bind(order_id)
    .fetch_all(pool)
    .await?)
}

pub async fn apply_command(
    pool: &PgPool,
    input: CommandInput,
) -> PersistenceResult<SweepOrderRecord> {
    let request_hash = hash_request_body(
        serde_json::to_vec(&json!({
            "order_id": input.order_id,
            "command": input.command.to_string(),
            "confirmation_ref": input.confirmation_ref.as_ref(),
            "external_order_ref": input.external_order_ref.as_ref(),
            "break_reason": input.break_reason.as_ref(),
        }))?
        .as_slice(),
    );
    let idempotency = input.idempotency_key.as_ref().map(|key| {
        (
            format!("order-command:{}:{}", input.order_id, input.command),
            hash_idempotency_key(key),
        )
    });

    let mut tx = pool.begin().await?;
    if let Some((scope, key_hash)) = idempotency.as_ref() {
        if let Some(order_id) =
            existing_idempotent_resource(&mut tx, scope, key_hash, &request_hash).await?
        {
            tx.commit().await?;
            return get_sweep_order(pool, order_id).await;
        }
    }

    let row = load_order_for_update(&mut tx, input.order_id).await?;
    let current = SweepStatus::from_str(&row.status)?;
    let outcome = transition(current, input.command, &input.guard_context)?;

    apply_side_effects(&mut tx, &row, &input, &outcome.to_status).await?;

    sqlx::query(
        r#"
        update sweep_orders
        set status = $2,
            updated_at = now(),
            external_order_ref = coalesce($3, external_order_ref),
            transfer_agent_confirmation_ref = coalesce($4, transfer_agent_confirmation_ref)
        where order_id = $1
        "#,
    )
    .bind(input.order_id)
    .bind(outcome.to_status.to_string())
    .bind(&input.external_order_ref)
    .bind(&input.confirmation_ref)
    .execute(&mut *tx)
    .await?;

    let event_types = outcome
        .emitted_events
        .iter()
        .map(|event| event.event_type())
        .collect::<Vec<_>>();
    insert_transition(
        &mut tx,
        TransitionInsert {
            order_id: input.order_id,
            from_status: Some(outcome.from_status.as_str()),
            to_status: outcome.to_status.as_str(),
            command: outcome.command.as_str(),
            emitted_events: json!(event_types),
            guard_results: serde_json::to_value(&outcome.guard_results)?,
            correlation_id: &input.correlation_id,
        },
    )
    .await?;

    for event in outcome.emitted_events {
        let envelope = EventEnvelope::new(
            event,
            input.order_id,
            input.correlation_id.clone(),
            None,
            None,
            event_payload(&event, &row, &input),
        );
        insert_event_records(&mut tx, &envelope).await?;
    }

    if let Some((scope, key_hash)) = idempotency.as_ref() {
        record_idempotency(
            &mut tx,
            scope,
            key_hash,
            &request_hash,
            Some(input.order_id),
            json!({"order_id": input.order_id}),
        )
        .await?;
    }
    tx.commit().await?;
    get_sweep_order(pool, input.order_id).await
}

pub async fn list_positions(
    pool: &PgPool,
    account_id: Uuid,
) -> PersistenceResult<Vec<PositionRecord>> {
    Ok(sqlx::query_as::<_, PositionRecord>(
        r#"
        select position_id, account_id, order_id, product_asset, quantity,
          transfer_agent_confirmation_ref, created_at
        from positions
        where account_id = $1
        order by created_at desc
        "#,
    )
    .bind(account_id)
    .fetch_all(pool)
    .await?)
}

pub async fn list_reconciliation_breaks(
    pool: &PgPool,
) -> PersistenceResult<Vec<ReconciliationBreakRecord>> {
    Ok(sqlx::query_as::<_, ReconciliationBreakRecord>(
        r#"
        select break_id, order_id, reason, status, details, created_at, resolved_at
        from reconciliation_breaks
        order by created_at desc
        "#,
    )
    .fetch_all(pool)
    .await?)
}

pub async fn resolve_reconciliation_break(
    pool: &PgPool,
    break_id: Uuid,
) -> PersistenceResult<ReconciliationBreakRecord> {
    sqlx::query_as::<_, ReconciliationBreakRecord>(
        r#"
        update reconciliation_breaks
        set status = 'Resolved', resolved_at = now()
        where break_id = $1
        returning break_id, order_id, reason, status, details, created_at, resolved_at
        "#,
    )
    .bind(break_id)
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| PersistenceError::NotFound(format!("reconciliation break {break_id}")))
}

pub async fn list_audit_events(
    pool: &PgPool,
    aggregate_id: Option<Uuid>,
) -> PersistenceResult<Vec<crate::AuditEventRecord>> {
    let rows = if let Some(aggregate_id) = aggregate_id {
        sqlx::query_as::<_, crate::AuditEventRecord>(
            r#"
            select event_id, aggregate_id, event_type, correlation_id, payload, created_at
            from audit_events
            where aggregate_id = $1
            order by created_at desc
            "#,
        )
        .bind(aggregate_id)
        .fetch_all(pool)
        .await?
    } else {
        sqlx::query_as::<_, crate::AuditEventRecord>(
            r#"
            select event_id, aggregate_id, event_type, correlation_id, payload, created_at
            from audit_events
            order by created_at desc
            limit 200
            "#,
        )
        .fetch_all(pool)
        .await?
    };
    Ok(rows)
}

pub async fn set_failure_injection(
    pool: &PgPool,
    key: &str,
    enabled: bool,
) -> PersistenceResult<()> {
    sqlx::query(
        r#"
        insert into failure_injections (key, value)
        values ($1, $2)
        on conflict (key) do update
        set value = excluded.value,
            updated_at = now()
        "#,
    )
    .bind(key)
    .bind(if enabled { "true" } else { "false" })
    .execute(pool)
    .await?;
    Ok(())
}

pub async fn get_failure_injection(pool: &PgPool, key: &str) -> PersistenceResult<bool> {
    let value: Option<(String,)> =
        sqlx::query_as("select value from failure_injections where key = $1")
            .bind(key)
            .fetch_optional(pool)
            .await?;
    Ok(matches!(
        value.as_ref().map(|row| row.0.as_str()),
        Some("true")
    ))
}

pub fn default_worker_guard_context() -> GuardContext {
    GuardContext::happy_path()
}

async fn ensure_account(
    tx: &mut Transaction<'_, Postgres>,
    account_id: Uuid,
) -> PersistenceResult<()> {
    sqlx::query(
        r#"
        insert into accounts (account_id)
        values ($1)
        on conflict (account_id) do nothing
        "#,
    )
    .bind(account_id)
    .execute(&mut **tx)
    .await?;
    Ok(())
}

async fn existing_idempotent_resource(
    tx: &mut Transaction<'_, Postgres>,
    scope: &str,
    key_hash: &str,
    request_hash: &str,
) -> PersistenceResult<Option<Uuid>> {
    let row: Option<(String, Option<Uuid>)> = sqlx::query_as(
        r#"
        select request_hash, resource_id
        from idempotency_records
        where scope = $1 and key_hash = $2
        "#,
    )
    .bind(scope)
    .bind(key_hash)
    .fetch_optional(&mut **tx)
    .await?;
    match row {
        Some((existing_hash, resource_id)) if existing_hash == request_hash => Ok(resource_id),
        Some(_) => Err(PersistenceError::IdempotencyConflict {
            scope: scope.to_string(),
        }),
        None => Ok(None),
    }
}

async fn record_idempotency(
    tx: &mut Transaction<'_, Postgres>,
    scope: &str,
    key_hash: &str,
    request_hash: &str,
    resource_id: Option<Uuid>,
    response_json: Value,
) -> PersistenceResult<()> {
    sqlx::query(
        r#"
        insert into idempotency_records
          (scope, key_hash, request_hash, resource_id, response_json)
        values ($1, $2, $3, $4, $5)
        on conflict (scope, key_hash) do nothing
        "#,
    )
    .bind(scope)
    .bind(key_hash)
    .bind(request_hash)
    .bind(resource_id)
    .bind(response_json)
    .execute(&mut **tx)
    .await?;
    Ok(())
}

async fn load_order_for_update(
    tx: &mut Transaction<'_, Postgres>,
    order_id: Uuid,
) -> PersistenceResult<SweepOrderRow> {
    sqlx::query_as::<_, SweepOrderRow>(
        r#"
        select order_id, account_id, idempotency_key_hash, correlation_id, status, amount,
          cash_asset, product_asset, external_order_ref, transfer_agent_confirmation_ref,
          created_at, updated_at
        from sweep_orders
        where order_id = $1
        for update
        "#,
    )
    .bind(order_id)
    .fetch_optional(&mut **tx)
    .await?
    .ok_or_else(|| PersistenceError::NotFound(format!("sweep order {order_id}")))
}

struct TransitionInsert<'a> {
    order_id: Uuid,
    from_status: Option<&'a str>,
    to_status: &'a str,
    command: &'a str,
    emitted_events: Value,
    guard_results: Value,
    correlation_id: &'a str,
}

async fn insert_transition(
    tx: &mut Transaction<'_, Postgres>,
    entry: TransitionInsert<'_>,
) -> PersistenceResult<()> {
    sqlx::query(
        r#"
        insert into state_transitions
          (transition_id, order_id, from_status, to_status, command, emitted_events, guard_results, correlation_id)
        values ($1, $2, $3, $4, $5, $6, $7, $8)
        "#,
    )
    .bind(Uuid::new_v4())
    .bind(entry.order_id)
    .bind(entry.from_status)
    .bind(entry.to_status)
    .bind(entry.command)
    .bind(entry.emitted_events)
    .bind(entry.guard_results)
    .bind(entry.correlation_id)
    .execute(&mut **tx)
    .await?;
    Ok(())
}

async fn insert_event_records(
    tx: &mut Transaction<'_, Postgres>,
    envelope: &EventEnvelope,
) -> PersistenceResult<()> {
    insert_outbox_event(tx, envelope).await?;
    sqlx::query(
        r#"
        insert into audit_events
          (event_id, aggregate_id, event_type, correlation_id, payload)
        values ($1, $2, $3, $4, $5)
        on conflict (event_id) do nothing
        "#,
    )
    .bind(envelope.event_id)
    .bind(envelope.aggregate_id)
    .bind(&envelope.event_type)
    .bind(&envelope.correlation_id)
    .bind(serde_json::to_value(envelope)?)
    .execute(&mut **tx)
    .await?;
    Ok(())
}

async fn apply_side_effects(
    tx: &mut Transaction<'_, Postgres>,
    row: &SweepOrderRow,
    input: &CommandInput,
    to_status: &SweepStatus,
) -> PersistenceResult<()> {
    match (input.command, to_status) {
        (SweepCommand::LockCash, SweepStatus::CashLocked) => {
            insert_balanced_ledger_entries(
                tx,
                LedgerPairInsert {
                    account_id: row.account_id,
                    order_id: row.order_id,
                    asset: &row.cash_asset,
                    amount: row.amount,
                    kind: LedgerEntryKind::CashLock,
                    debit_account: "customer_cash",
                    credit_account: "locked_cash",
                },
            )
            .await?;
        }
        (SweepCommand::ConfirmTransferAgent, SweepStatus::TransferAgentConfirmed) => {
            validate_position_booking_confirmation(input.confirmation_ref.as_deref())?;
        }
        (SweepCommand::BookPosition, SweepStatus::PositionBooked) => {
            let confirmation_ref = input
                .confirmation_ref
                .as_deref()
                .or(row.transfer_agent_confirmation_ref.as_deref())
                .ok_or(PersistenceError::MissingConfirmation(row.order_id))?;
            validate_position_booking_confirmation(Some(confirmation_ref))?;
            let position_id = Uuid::new_v4();
            sqlx::query(
                r#"
                insert into positions
                  (position_id, account_id, order_id, product_asset, quantity, transfer_agent_confirmation_ref)
                values ($1, $2, $3, $4, $5, $6)
                on conflict (order_id) do nothing
                "#,
            )
            .bind(position_id)
            .bind(row.account_id)
            .bind(row.order_id)
            .bind(&row.product_asset)
            .bind(row.amount)
            .bind(confirmation_ref)
            .execute(&mut **tx)
            .await?;
            insert_balanced_ledger_entries(
                tx,
                LedgerPairInsert {
                    account_id: row.account_id,
                    order_id: row.order_id,
                    asset: &row.product_asset,
                    amount: row.amount,
                    kind: LedgerEntryKind::PositionBooking,
                    debit_account: "product_position",
                    credit_account: "subscription_clearing",
                },
            )
            .await?;
        }
        (SweepCommand::OpenException, SweepStatus::ExceptionOpen) => {
            let reason = input
                .break_reason
                .clone()
                .unwrap_or_else(|| "reconciliation mismatch".to_string());
            sqlx::query(
                r#"
                insert into reconciliation_breaks
                  (break_id, order_id, reason, status, details)
                values ($1, $2, $3, 'Open', $4)
                "#,
            )
            .bind(Uuid::new_v4())
            .bind(row.order_id)
            .bind(reason)
            .bind(json!({"source": "local-reconciliation-worker"}))
            .execute(&mut **tx)
            .await?;
        }
        _ => {}
    }
    Ok(())
}

struct LedgerPairInsert<'a> {
    account_id: Uuid,
    order_id: Uuid,
    asset: &'a str,
    amount: Decimal,
    kind: LedgerEntryKind,
    debit_account: &'a str,
    credit_account: &'a str,
}

async fn insert_balanced_ledger_entries(
    tx: &mut Transaction<'_, Postgres>,
    insert: LedgerPairInsert<'_>,
) -> PersistenceResult<()> {
    let entries = [
        LedgerEntry {
            entry_id: Uuid::new_v4(),
            account_id: insert.account_id,
            order_id: Some(insert.order_id),
            asset: Asset::from_str(insert.asset)?,
            amount: insert.amount,
            side: DebitCredit::Debit,
            ledger_account: insert.debit_account.to_string(),
            kind: insert.kind,
        },
        LedgerEntry {
            entry_id: Uuid::new_v4(),
            account_id: insert.account_id,
            order_id: Some(insert.order_id),
            asset: Asset::from_str(insert.asset)?,
            amount: insert.amount,
            side: DebitCredit::Credit,
            ledger_account: insert.credit_account.to_string(),
            kind: insert.kind,
        },
    ];
    institutional_yield_domain::validate_ledger_balances(&entries)?;
    for entry in entries {
        sqlx::query(
            r#"
            insert into ledger_entries
              (entry_id, account_id, order_id, asset, amount, debit_credit, ledger_account, entry_kind)
            values ($1, $2, $3, $4, $5, $6, $7, $8)
            "#,
        )
        .bind(entry.entry_id)
        .bind(entry.account_id)
        .bind(entry.order_id)
        .bind(entry.asset.to_string())
        .bind(entry.amount)
        .bind(match entry.side {
            DebitCredit::Debit => "Debit",
            DebitCredit::Credit => "Credit",
        })
        .bind(entry.ledger_account)
        .bind(format!("{:?}", entry.kind))
        .execute(&mut **tx)
        .await?;
    }
    Ok(())
}

fn event_payload(event: &DomainEvent, row: &SweepOrderRow, input: &CommandInput) -> Value {
    match event {
        DomainEvent::SweepTransferAgentConfirmed => json!({
            "order_id": row.order_id,
            "confirmation_ref": input.confirmation_ref
        }),
        DomainEvent::SweepPositionBooked => json!({
            "order_id": row.order_id,
            "product_asset": row.product_asset,
            "quantity": row.amount.to_string(),
            "confirmation_ref": input.confirmation_ref.as_ref().or(row.transfer_agent_confirmation_ref.as_ref())
        }),
        DomainEvent::ReconciliationBreakOpened => json!({
            "order_id": row.order_id,
            "reason": input.break_reason
        }),
        _ => json!({
            "order_id": row.order_id,
            "account_id": row.account_id,
            "amount": row.amount.to_string(),
            "cash_asset": row.cash_asset,
            "product_asset": row.product_asset
        }),
    }
}
