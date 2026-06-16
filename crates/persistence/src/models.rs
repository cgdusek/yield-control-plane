use chrono::{DateTime, Utc};
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct SweepPolicyRecord {
    pub account_id: Uuid,
    pub minimum_cash_balance: Decimal,
    pub target_product: String,
    pub enabled: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct SweepOrderRow {
    pub order_id: Uuid,
    pub account_id: Uuid,
    pub idempotency_key_hash: String,
    pub correlation_id: String,
    pub status: String,
    pub amount: Decimal,
    pub cash_asset: String,
    pub product_asset: String,
    pub external_order_ref: Option<String>,
    pub transfer_agent_confirmation_ref: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SweepOrderRecord {
    pub order_id: Uuid,
    pub account_id: Uuid,
    pub status: String,
    pub amount: Decimal,
    pub cash_asset: String,
    pub product_asset: String,
    pub external_order_ref: Option<String>,
    pub transfer_agent_confirmation_ref: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub timeline: Vec<TimelineEntryRecord>,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct TimelineEntryRecord {
    pub transition_id: Uuid,
    pub order_id: Uuid,
    pub from_status: Option<String>,
    pub to_status: String,
    pub command: String,
    pub correlation_id: String,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct PositionRecord {
    pub position_id: Uuid,
    pub account_id: Uuid,
    pub order_id: Uuid,
    pub product_asset: String,
    pub quantity: Decimal,
    pub transfer_agent_confirmation_ref: String,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct ReconciliationBreakRecord {
    pub break_id: Uuid,
    pub order_id: Uuid,
    pub reason: String,
    pub status: String,
    pub details: Value,
    pub created_at: DateTime<Utc>,
    pub resolved_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct OutboxEventRecord {
    pub event_id: Uuid,
    pub event_type: String,
    pub aggregate_id: Uuid,
    pub correlation_id: String,
    pub causation_id: Option<Uuid>,
    pub payload: Value,
    pub status: String,
    pub attempts: i32,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct AuditEventRecord {
    pub event_id: Uuid,
    pub aggregate_id: Uuid,
    pub event_type: String,
    pub correlation_id: String,
    pub payload: Value,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone)]
pub struct CreateSweepPolicyInput {
    pub account_id: Uuid,
    pub minimum_cash_balance: Decimal,
    pub target_product: String,
    pub idempotency_key: String,
    pub correlation_id: String,
}

#[derive(Debug, Clone)]
pub struct CreateSweepOrderInput {
    pub account_id: Uuid,
    pub amount: Decimal,
    pub cash_asset: String,
    pub product_asset: String,
    pub idempotency_key: String,
    pub correlation_id: String,
}

#[derive(Debug, Clone)]
pub struct CommandInput {
    pub order_id: Uuid,
    pub command: institutional_yield_domain::SweepCommand,
    pub correlation_id: String,
    pub idempotency_key: Option<String>,
    pub confirmation_ref: Option<String>,
    pub external_order_ref: Option<String>,
    pub break_reason: Option<String>,
    pub guard_context: institutional_yield_domain::GuardContext,
}
