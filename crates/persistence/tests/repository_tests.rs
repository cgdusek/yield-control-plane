use institutional_yield_domain::{GuardContext, SweepCommand};
use institutional_yield_persistence::{
    connect, create_sweep_order, list_positions, migrate, repositories::apply_command,
    CreateSweepOrderInput, PersistenceError,
};
use rust_decimal::Decimal;
use sqlx::PgPool;
use std::{env, str::FromStr};
use tokio::sync::{Mutex, MutexGuard};
use uuid::Uuid;

static DB_TEST_LOCK: Mutex<()> = Mutex::const_new(());

struct DbTest {
    pool: PgPool,
    _guard: MutexGuard<'static, ()>,
}

async fn test_pool() -> Option<DbTest> {
    if env::var("RUN_DATABASE_TESTS").ok().as_deref() != Some("1") {
        eprintln!("RUN_DATABASE_TESTS=1 not set; skipping Postgres-backed persistence test");
        return None;
    }
    let guard = DB_TEST_LOCK.lock().await;
    let database_url = env::var("DATABASE_URL")
        .unwrap_or_else(|_| "postgres://yield:yield@localhost:15432/yield_control".to_string());
    let pool = connect(&database_url)
        .await
        .expect("connect to test Postgres");
    migrate(&pool).await.expect("apply migrations");
    sqlx::query(
        r#"
        truncate table
          failure_injections,
          inbox_messages,
          outbox_events,
          audit_events,
          reconciliation_breaks,
          positions,
          ledger_entries,
          state_transitions,
          sweep_orders,
          sweep_policies,
          accounts
        cascade
        "#,
    )
    .execute(&pool)
    .await
    .expect("truncate test database");
    Some(DbTest {
        pool,
        _guard: guard,
    })
}

fn order_input(account_id: Uuid, key: &str, amount: &str) -> CreateSweepOrderInput {
    CreateSweepOrderInput {
        account_id,
        amount: Decimal::from_str(amount).expect("valid decimal"),
        cash_asset: "USD".to_string(),
        product_asset: "FYOXX".to_string(),
        idempotency_key: key.to_string(),
        correlation_id: "test-correlation".to_string(),
    }
}

async fn command(pool: &PgPool, order_id: Uuid, command: SweepCommand) {
    apply_command(
        pool,
        institutional_yield_persistence::CommandInput {
            order_id,
            command,
            correlation_id: "test-correlation".to_string(),
            idempotency_key: None,
            confirmation_ref: None,
            external_order_ref: None,
            break_reason: None,
            guard_context: GuardContext::happy_path(),
        },
    )
    .await
    .expect("command applies");
}

async fn drive_to_subscription(pool: &PgPool, order_id: Uuid) {
    command(pool, order_id, SweepCommand::CheckEligibility).await;
    command(pool, order_id, SweepCommand::CheckDisclosures).await;
    command(pool, order_id, SweepCommand::Approve).await;
    command(pool, order_id, SweepCommand::LockCash).await;
    command(pool, order_id, SweepCommand::SubmitSubscription).await;
}

#[tokio::test]
async fn duplicate_idempotency_key_reuses_order() {
    let Some(db) = test_pool().await else {
        return;
    };
    let pool = &db.pool;
    let account_id = Uuid::new_v4();
    let first = create_sweep_order(pool, order_input(account_id, "dup-key", "10.00"))
        .await
        .expect("first order");
    let second = create_sweep_order(pool, order_input(account_id, "dup-key", "10.00"))
        .await
        .expect("duplicate order replay");
    assert_eq!(first.order_id, second.order_id);
}

#[tokio::test]
async fn duplicate_idempotency_key_with_different_body_conflicts() {
    let Some(db) = test_pool().await else {
        return;
    };
    let pool = &db.pool;
    let account_id = Uuid::new_v4();
    create_sweep_order(pool, order_input(account_id, "dup-key", "10.00"))
        .await
        .expect("first order");
    let error = create_sweep_order(pool, order_input(account_id, "dup-key", "11.00"))
        .await
        .expect_err("different replay must conflict");
    assert!(matches!(
        error,
        PersistenceError::IdempotencyConflict { .. }
    ));
}

#[tokio::test]
async fn duplicate_confirmation_ref_cannot_double_book() {
    let Some(db) = test_pool().await else {
        return;
    };
    let pool = &db.pool;
    let account_id = Uuid::new_v4();
    let first = create_sweep_order(pool, order_input(account_id, "first", "10.00"))
        .await
        .expect("first order");
    drive_to_subscription(pool, first.order_id).await;
    apply_command(
        pool,
        institutional_yield_persistence::CommandInput {
            order_id: first.order_id,
            command: SweepCommand::ConfirmTransferAgent,
            correlation_id: "test-correlation".to_string(),
            idempotency_key: None,
            confirmation_ref: Some("ta-confirmation-1".to_string()),
            external_order_ref: None,
            break_reason: None,
            guard_context: GuardContext::happy_path(),
        },
    )
    .await
    .expect("confirm first");
    apply_command(
        pool,
        institutional_yield_persistence::CommandInput {
            order_id: first.order_id,
            command: SweepCommand::BookPosition,
            correlation_id: "test-correlation".to_string(),
            idempotency_key: None,
            confirmation_ref: Some("ta-confirmation-1".to_string()),
            external_order_ref: None,
            break_reason: None,
            guard_context: GuardContext::happy_path(),
        },
    )
    .await
    .expect("book first");
    assert_eq!(
        list_positions(pool, account_id)
            .await
            .expect("positions")
            .len(),
        1
    );

    let second = create_sweep_order(pool, order_input(account_id, "second", "12.00"))
        .await
        .expect("second order");
    drive_to_subscription(pool, second.order_id).await;
    let duplicate = apply_command(
        pool,
        institutional_yield_persistence::CommandInput {
            order_id: second.order_id,
            command: SweepCommand::ConfirmTransferAgent,
            correlation_id: "test-correlation".to_string(),
            idempotency_key: None,
            confirmation_ref: Some("ta-confirmation-1".to_string()),
            external_order_ref: None,
            break_reason: None,
            guard_context: GuardContext::happy_path(),
        },
    )
    .await;
    assert!(duplicate.is_err());
    assert_eq!(
        list_positions(pool, account_id)
            .await
            .expect("positions")
            .len(),
        1
    );
}

#[tokio::test]
async fn attempted_fidd_yield_source_is_rejected() {
    let Some(db) = test_pool().await else {
        return;
    };
    let pool = &db.pool;
    let mut input = order_input(Uuid::new_v4(), "fidd-yield", "10.00");
    input.product_asset = "FIDD".to_string();
    let error = create_sweep_order(pool, input)
        .await
        .expect_err("FIDD cannot be yield-bearing product");
    assert!(matches!(error, PersistenceError::Domain(_)));
}

#[tokio::test]
async fn ledger_entries_are_append_only() {
    let Some(db) = test_pool().await else {
        return;
    };
    let pool = &db.pool;
    let order = create_sweep_order(pool, order_input(Uuid::new_v4(), "ledger", "10.00"))
        .await
        .expect("order");
    command(pool, order.order_id, SweepCommand::CheckEligibility).await;
    command(pool, order.order_id, SweepCommand::CheckDisclosures).await;
    command(pool, order.order_id, SweepCommand::Approve).await;
    command(pool, order.order_id, SweepCommand::LockCash).await;
    let result = sqlx::query("update ledger_entries set amount = amount where order_id = $1")
        .bind(order.order_id)
        .execute(pool)
        .await;
    assert!(result.is_err());
}
