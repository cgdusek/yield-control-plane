use crate::{
    error::{map_domain, map_persistence, ApiError},
    middleware::require_write_headers,
    openapi::openapi_yaml,
    AppState,
};
use axum::{
    extract::{Path, Query, State},
    http::{HeaderMap, StatusCode},
    response::IntoResponse,
    routing::{get, post},
    Json, Router,
};
use institutional_yield_domain::{invariants::ensure_yield_source_allowed, Asset, SweepCommand};
use institutional_yield_observability::metrics_snapshot;
use institutional_yield_persistence::{
    apply_command, create_sweep_order, create_sweep_policy, default_worker_guard_context,
    get_failure_injection, get_sweep_order, get_sweep_policy, list_audit_events, list_positions,
    list_reconciliation_breaks, resolve_reconciliation_break, set_failure_injection, CommandInput,
    CreateSweepOrderInput, CreateSweepPolicyInput, SweepOrderRecord,
};
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use std::{collections::HashMap, str::FromStr};
use uuid::Uuid;

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/health", get(health))
        .route("/ready", get(ready))
        .route("/metrics", get(metrics))
        .route("/openapi.yaml", get(openapi))
        .route("/sweep-policies", post(create_policy))
        .route("/sweep-policies/{account_id}", get(get_policy))
        .route("/sweep-orders", post(create_order))
        .route("/sweep-orders/{order_id}", get(get_order))
        .route("/sweep-orders/{order_id}/approve", post(approve_order))
        .route("/sweep-orders/{order_id}/cancel", post(cancel_order))
        .route("/redemptions", post(request_redemption))
        .route("/accounts/{account_id}/positions", get(positions))
        .route("/accounts/{account_id}/income", get(income))
        .route("/reconciliation-breaks", get(reconciliation_breaks))
        .route(
            "/reconciliation-breaks/{break_id}/resolve",
            post(resolve_break),
        )
        .route("/audit-events", get(audit_events))
        .route("/dev/attempt-fidd-yield", post(attempt_fidd_yield))
        .route(
            "/dev/failure-injections/reconciliation-mismatch",
            post(set_reconciliation_mismatch),
        )
}

#[derive(Debug, Serialize)]
struct HealthResponse {
    status: String,
    service: String,
}

async fn health() -> Json<HealthResponse> {
    Json(HealthResponse {
        status: "ok".to_string(),
        service: "api".to_string(),
    })
}

async fn ready(State(state): State<AppState>) -> Result<Json<HealthResponse>, ApiError> {
    sqlx::query("select 1")
        .execute(&state.pool)
        .await
        .map_err(|error| {
            ApiError::new(
                StatusCode::SERVICE_UNAVAILABLE,
                "not_ready",
                error.to_string(),
                "ready-check",
            )
        })?;
    Ok(Json(HealthResponse {
        status: "ready".to_string(),
        service: "api".to_string(),
    }))
}

async fn metrics() -> impl IntoResponse {
    metrics_snapshot("api")
}

async fn openapi() -> impl IntoResponse {
    (
        [(axum::http::header::CONTENT_TYPE, "application/yaml")],
        openapi_yaml(),
    )
}

#[derive(Debug, Deserialize)]
struct CreatePolicyRequest {
    account_id: Uuid,
    minimum_cash_balance: String,
    target_product: String,
}

async fn create_policy(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<CreatePolicyRequest>,
) -> Result<Json<PolicyResponse>, ApiError> {
    let required = require_write_headers(&headers)?;
    let minimum_cash_balance = decimal(&body.minimum_cash_balance, &required.correlation_id)?;
    let policy = create_sweep_policy(
        &state.pool,
        CreateSweepPolicyInput {
            account_id: body.account_id,
            minimum_cash_balance,
            target_product: body.target_product,
            idempotency_key: required.idempotency_key,
            correlation_id: required.correlation_id.clone(),
        },
    )
    .await
    .map_err(|error| map_persistence(error, &required.correlation_id))?;
    Ok(Json(PolicyResponse {
        account_id: policy.account_id,
        minimum_cash_balance: policy.minimum_cash_balance.to_string(),
        target_product: policy.target_product,
        enabled: policy.enabled,
    }))
}

async fn get_policy(
    State(state): State<AppState>,
    Path(account_id): Path<Uuid>,
) -> Result<Json<PolicyResponse>, ApiError> {
    let policy = get_sweep_policy(&state.pool, account_id)
        .await
        .map_err(|error| map_persistence(error, "get-policy"))?;
    Ok(Json(PolicyResponse {
        account_id: policy.account_id,
        minimum_cash_balance: policy.minimum_cash_balance.to_string(),
        target_product: policy.target_product,
        enabled: policy.enabled,
    }))
}

#[derive(Debug, Serialize)]
struct PolicyResponse {
    account_id: Uuid,
    minimum_cash_balance: String,
    target_product: String,
    enabled: bool,
}

#[derive(Debug, Deserialize)]
struct CreateOrderRequest {
    account_id: Uuid,
    amount: String,
    cash_asset: String,
    product_asset: String,
}

async fn create_order(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<CreateOrderRequest>,
) -> Result<Json<SweepOrderResponse>, ApiError> {
    let required = require_write_headers(&headers)?;
    let amount = decimal(&body.amount, &required.correlation_id)?;
    let order = create_sweep_order(
        &state.pool,
        CreateSweepOrderInput {
            account_id: body.account_id,
            amount,
            cash_asset: body.cash_asset,
            product_asset: body.product_asset,
            idempotency_key: required.idempotency_key,
            correlation_id: required.correlation_id.clone(),
        },
    )
    .await
    .map_err(|error| map_persistence(error, &required.correlation_id))?;
    Ok(Json(order_response(order)))
}

async fn get_order(
    State(state): State<AppState>,
    Path(order_id): Path<Uuid>,
) -> Result<Json<SweepOrderResponse>, ApiError> {
    let order = get_sweep_order(&state.pool, order_id)
        .await
        .map_err(|error| map_persistence(error, "get-order"))?;
    Ok(Json(order_response(order)))
}

async fn approve_order(
    State(state): State<AppState>,
    Path(order_id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<Json<SweepOrderResponse>, ApiError> {
    let required = require_write_headers(&headers)?;
    let mut order = get_sweep_order(&state.pool, order_id)
        .await
        .map_err(|error| map_persistence(error, &required.correlation_id))?;
    for command in [
        SweepCommand::CheckEligibility,
        SweepCommand::CheckDisclosures,
        SweepCommand::Approve,
    ] {
        if matches!(
            order.status.as_str(),
            "Approved"
                | "CashLocked"
                | "SubscriptionSubmitted"
                | "TransferAgentConfirmed"
                | "ChainMirrorObserved"
                | "PositionBooked"
                | "Reconciled"
                | "Active"
        ) {
            break;
        }
        order = apply_order_command(
            &state,
            order_id,
            command,
            &required.correlation_id,
            if command == SweepCommand::Approve {
                Some(required.idempotency_key.clone())
            } else {
                None
            },
            None,
            None,
        )
        .await?;
    }
    Ok(Json(order_response(order)))
}

async fn cancel_order(
    State(state): State<AppState>,
    Path(order_id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<Json<SweepOrderResponse>, ApiError> {
    let required = require_write_headers(&headers)?;
    let order = apply_order_command(
        &state,
        order_id,
        SweepCommand::Cancel,
        &required.correlation_id,
        Some(required.idempotency_key),
        None,
        None,
    )
    .await?;
    Ok(Json(order_response(order)))
}

#[derive(Debug, Deserialize)]
struct RedemptionRequest {
    order_id: Uuid,
}

async fn request_redemption(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<RedemptionRequest>,
) -> Result<Json<SweepOrderResponse>, ApiError> {
    let required = require_write_headers(&headers)?;
    let order = apply_order_command(
        &state,
        body.order_id,
        SweepCommand::RequestRedemption,
        &required.correlation_id,
        Some(required.idempotency_key),
        None,
        None,
    )
    .await?;
    Ok(Json(order_response(order)))
}

async fn positions(
    State(state): State<AppState>,
    Path(account_id): Path<Uuid>,
) -> Result<Json<Vec<PositionResponse>>, ApiError> {
    let positions = list_positions(&state.pool, account_id)
        .await
        .map_err(|error| map_persistence(error, "positions"))?
        .into_iter()
        .map(|position| PositionResponse {
            position_id: position.position_id,
            account_id: position.account_id,
            order_id: position.order_id,
            product_asset: position.product_asset,
            quantity: position.quantity.to_string(),
            transfer_agent_confirmation_ref: position.transfer_agent_confirmation_ref,
        })
        .collect();
    Ok(Json(positions))
}

async fn income(Path(_account_id): Path<Uuid>) -> Json<Vec<IncomeResponse>> {
    Json(Vec::new())
}

async fn reconciliation_breaks(
    State(state): State<AppState>,
) -> Result<Json<Vec<ReconciliationBreakResponse>>, ApiError> {
    let breaks = list_reconciliation_breaks(&state.pool)
        .await
        .map_err(|error| map_persistence(error, "reconciliation-breaks"))?
        .into_iter()
        .map(|item| ReconciliationBreakResponse {
            break_id: item.break_id,
            order_id: item.order_id,
            reason: item.reason,
            status: item.status,
            created_at: item.created_at.to_rfc3339(),
        })
        .collect();
    Ok(Json(breaks))
}

async fn resolve_break(
    State(state): State<AppState>,
    Path(break_id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<Json<ReconciliationBreakResponse>, ApiError> {
    let required = require_write_headers(&headers)?;
    let item = resolve_reconciliation_break(&state.pool, break_id)
        .await
        .map_err(|error| map_persistence(error, &required.correlation_id))?;
    Ok(Json(ReconciliationBreakResponse {
        break_id: item.break_id,
        order_id: item.order_id,
        reason: item.reason,
        status: item.status,
        created_at: item.created_at.to_rfc3339(),
    }))
}

async fn audit_events(
    State(state): State<AppState>,
    Query(query): Query<HashMap<String, String>>,
) -> Result<Json<Vec<AuditEventResponse>>, ApiError> {
    let aggregate_id = query
        .get("aggregate_id")
        .map(|value| Uuid::parse_str(value))
        .transpose()
        .map_err(|error| {
            ApiError::new(
                StatusCode::BAD_REQUEST,
                "invalid_uuid",
                error.to_string(),
                "audit-events",
            )
        })?;
    let events = list_audit_events(&state.pool, aggregate_id)
        .await
        .map_err(|error| map_persistence(error, "audit-events"))?
        .into_iter()
        .map(|event| AuditEventResponse {
            event_id: event.event_id,
            aggregate_id: event.aggregate_id,
            event_type: event.event_type,
            correlation_id: event.correlation_id,
            created_at: event.created_at.to_rfc3339(),
        })
        .collect();
    Ok(Json(events))
}

#[derive(Debug, Deserialize)]
struct AttemptFiddYieldRequest {
    account_id: Uuid,
    amount: String,
}

async fn attempt_fidd_yield(
    headers: HeaderMap,
    Json(body): Json<AttemptFiddYieldRequest>,
) -> Result<Json<serde_json::Value>, ApiError> {
    let required = require_write_headers(&headers)?;
    let _amount = decimal(&body.amount, &required.correlation_id)?;
    let _account_id = body.account_id;
    ensure_yield_source_allowed(&Asset::FIDD)
        .map_err(|error| map_domain(error, &required.correlation_id))?;
    Ok(Json(serde_json::json!({"accepted": true})))
}

#[derive(Debug, Deserialize)]
struct FailureInjectionRequest {
    enabled: bool,
}

async fn set_reconciliation_mismatch(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<FailureInjectionRequest>,
) -> Result<Json<serde_json::Value>, ApiError> {
    let required = require_write_headers(&headers)?;
    set_failure_injection(&state.pool, "reconciliation-mismatch", body.enabled)
        .await
        .map_err(|error| map_persistence(error, &required.correlation_id))?;
    let enabled = get_failure_injection(&state.pool, "reconciliation-mismatch")
        .await
        .map_err(|error| map_persistence(error, &required.correlation_id))?;
    Ok(Json(
        serde_json::json!({"reconciliation_mismatch": enabled}),
    ))
}

async fn apply_order_command(
    state: &AppState,
    order_id: Uuid,
    command: SweepCommand,
    correlation_id: &str,
    idempotency_key: Option<String>,
    confirmation_ref: Option<String>,
    break_reason: Option<String>,
) -> Result<SweepOrderRecord, ApiError> {
    apply_command(
        &state.pool,
        CommandInput {
            order_id,
            command,
            correlation_id: correlation_id.to_string(),
            idempotency_key,
            confirmation_ref,
            external_order_ref: None,
            break_reason,
            guard_context: default_worker_guard_context(),
        },
    )
    .await
    .map_err(|error| map_persistence(error, correlation_id))
}

fn decimal(value: &str, correlation_id: &str) -> Result<Decimal, ApiError> {
    Decimal::from_str(value).map_err(|error| {
        ApiError::new(
            StatusCode::UNPROCESSABLE_ENTITY,
            "invalid_decimal",
            error.to_string(),
            correlation_id.to_string(),
        )
    })
}

#[derive(Debug, Serialize)]
struct SweepOrderResponse {
    order_id: Uuid,
    account_id: Uuid,
    status: String,
    amount: String,
    cash_asset: String,
    product_asset: String,
    transfer_agent_confirmation_ref: Option<String>,
    timeline: Vec<TimelineResponse>,
}

#[derive(Debug, Serialize)]
struct TimelineResponse {
    from_status: Option<String>,
    to_status: String,
    command: String,
    occurred_at: String,
}

fn order_response(order: SweepOrderRecord) -> SweepOrderResponse {
    SweepOrderResponse {
        order_id: order.order_id,
        account_id: order.account_id,
        status: order.status,
        amount: order.amount.to_string(),
        cash_asset: order.cash_asset,
        product_asset: order.product_asset,
        transfer_agent_confirmation_ref: order.transfer_agent_confirmation_ref,
        timeline: order
            .timeline
            .into_iter()
            .map(|entry| TimelineResponse {
                from_status: entry.from_status,
                to_status: entry.to_status,
                command: entry.command,
                occurred_at: entry.created_at.to_rfc3339(),
            })
            .collect(),
    }
}

#[derive(Debug, Serialize)]
struct PositionResponse {
    position_id: Uuid,
    account_id: Uuid,
    order_id: Uuid,
    product_asset: String,
    quantity: String,
    transfer_agent_confirmation_ref: String,
}

#[derive(Debug, Serialize)]
struct IncomeResponse {
    asset: String,
    amount: String,
    source: String,
}

#[derive(Debug, Serialize)]
struct ReconciliationBreakResponse {
    break_id: Uuid,
    order_id: Uuid,
    reason: String,
    status: String,
    created_at: String,
}

#[derive(Debug, Serialize)]
struct AuditEventResponse {
    event_id: Uuid,
    aggregate_id: Uuid,
    event_type: String,
    correlation_id: String,
    created_at: String,
}
