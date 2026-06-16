use axum::{
    extract::{Path, State},
    http::StatusCode,
    routing::{get, post},
    Json, Router,
};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::{collections::HashMap, net::SocketAddr, sync::Arc};
use tokio::sync::RwLock;
use uuid::Uuid;

#[derive(Clone, Default)]
struct AppState {
    confirmations: Arc<RwLock<HashMap<String, ConfirmationResponse>>>,
    failure_mode: Arc<RwLock<Option<String>>>,
}

#[derive(Debug, Deserialize)]
struct SubscriptionRequest {
    order_id: Uuid,
    idempotency_key: String,
    amount: String,
    product_asset: String,
}

#[derive(Debug, Clone, Serialize)]
struct ConfirmationResponse {
    order_id: Uuid,
    confirmation_ref: String,
    amount: String,
    product_asset: String,
    status: String,
}

#[derive(Debug, Deserialize)]
struct FailureModeRequest {
    mode: Option<String>,
}

#[derive(Debug, Serialize)]
struct Health {
    status: String,
    service: String,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let bind = std::env::var("MOCK_TRANSFER_AGENT_BIND_ADDR")
        .unwrap_or_else(|_| "0.0.0.0:8090".to_string());
    let addr: SocketAddr = bind.parse()?;
    let app = app();
    tracing::info!(%addr, "mock transfer agent listening");
    axum::serve(tokio::net::TcpListener::bind(addr).await?, app)
        .with_graceful_shutdown(shutdown_signal())
        .await?;
    Ok(())
}

fn app() -> Router {
    Router::new()
        .route("/health", get(health))
        .route("/subscriptions", post(create_subscription))
        .route("/subscriptions/{idempotency_key}", get(get_subscription))
        .route("/admin/failure-mode", post(set_failure_mode))
        .with_state(AppState::default())
}

async fn health() -> Json<Health> {
    Json(Health {
        status: "ok".to_string(),
        service: "mock-transfer-agent".to_string(),
    })
}

async fn create_subscription(
    State(state): State<AppState>,
    Json(body): Json<SubscriptionRequest>,
) -> Result<Json<ConfirmationResponse>, StatusCode> {
    if state.failure_mode.read().await.as_deref() == Some("fail") {
        return Err(StatusCode::SERVICE_UNAVAILABLE);
    }
    let mut confirmations = state.confirmations.write().await;
    if let Some(existing) = confirmations.get(&body.idempotency_key) {
        return Ok(Json(existing.clone()));
    }
    let confirmation = ConfirmationResponse {
        order_id: body.order_id,
        confirmation_ref: format!("ta-{}", short_hash(&body.idempotency_key)),
        amount: body.amount,
        product_asset: body.product_asset,
        status: "confirmed".to_string(),
    };
    confirmations.insert(body.idempotency_key, confirmation.clone());
    Ok(Json(confirmation))
}

async fn get_subscription(
    State(state): State<AppState>,
    Path(idempotency_key): Path<String>,
) -> Result<Json<ConfirmationResponse>, StatusCode> {
    state
        .confirmations
        .read()
        .await
        .get(&idempotency_key)
        .cloned()
        .map(Json)
        .ok_or(StatusCode::NOT_FOUND)
}

async fn set_failure_mode(
    State(state): State<AppState>,
    Json(body): Json<FailureModeRequest>,
) -> Json<serde_json::Value> {
    *state.failure_mode.write().await = body.mode.clone();
    Json(serde_json::json!({ "mode": body.mode }))
}

fn short_hash(value: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(value.as_bytes());
    hex::encode(&hasher.finalize()[..8])
}

async fn shutdown_signal() {
    let _ = tokio::signal::ctrl_c().await;
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::{body::Body, http::Request};
    use tower::ServiceExt;

    #[tokio::test]
    async fn repeated_idempotency_key_returns_same_confirmation() {
        let body = r#"{"order_id":"11111111-1111-4111-8111-111111111111","idempotency_key":"same","amount":"10.00","product_asset":"FYOXX"}"#;
        let first = app()
            .oneshot(
                Request::builder()
                    .method("POST")
                    .uri("/subscriptions")
                    .header("Content-Type", "application/json")
                    .body(Body::from(body))
                    .expect("request"),
            )
            .await
            .expect("first");
        let second = app()
            .oneshot(
                Request::builder()
                    .method("POST")
                    .uri("/subscriptions")
                    .header("Content-Type", "application/json")
                    .body(Body::from(body))
                    .expect("request"),
            )
            .await
            .expect("second");
        assert_eq!(first.status(), StatusCode::OK);
        assert_eq!(second.status(), StatusCode::OK);
    }
}
