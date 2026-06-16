use axum::{http::StatusCode, response::IntoResponse, Json};
use institutional_yield_domain::DomainError;
use institutional_yield_persistence::PersistenceError;
use serde::Serialize;

#[derive(Debug, Clone, Serialize)]
pub struct ErrorResponse {
    pub code: String,
    pub message: String,
    pub correlation_id: String,
}

#[derive(Debug)]
pub struct ApiError {
    pub status: StatusCode,
    pub response: ErrorResponse,
}

impl ApiError {
    pub fn new(
        status: StatusCode,
        code: impl Into<String>,
        message: impl Into<String>,
        correlation_id: impl Into<String>,
    ) -> Self {
        Self {
            status,
            response: ErrorResponse {
                code: code.into(),
                message: message.into(),
                correlation_id: correlation_id.into(),
            },
        }
    }
}

impl IntoResponse for ApiError {
    fn into_response(self) -> axum::response::Response {
        (self.status, Json(self.response)).into_response()
    }
}

pub fn map_persistence(error: PersistenceError, correlation_id: &str) -> ApiError {
    match error {
        PersistenceError::NotFound(message) => ApiError::new(
            StatusCode::NOT_FOUND,
            "not_found",
            message,
            correlation_id.to_string(),
        ),
        PersistenceError::IdempotencyConflict { scope } => ApiError::new(
            StatusCode::CONFLICT,
            "idempotency_conflict",
            format!("idempotency key replay changed request body for {scope}"),
            correlation_id.to_string(),
        ),
        PersistenceError::Domain(domain) => map_domain(domain, correlation_id),
        other => ApiError::new(
            StatusCode::INTERNAL_SERVER_ERROR,
            "persistence_error",
            other.to_string(),
            correlation_id.to_string(),
        ),
    }
}

pub fn map_domain(error: DomainError, correlation_id: &str) -> ApiError {
    match error {
        DomainError::InvalidTransition { .. } => ApiError::new(
            StatusCode::CONFLICT,
            "invalid_transition",
            error.to_string(),
            correlation_id.to_string(),
        ),
        DomainError::GuardFailed { .. }
        | DomainError::YieldOnCashRailForbidden { .. }
        | DomainError::MissingTransferAgentConfirmation
        | DomainError::NegativeAmount
        | DomainError::AssetMismatch
        | DomainError::Parse(_) => ApiError::new(
            StatusCode::UNPROCESSABLE_ENTITY,
            "domain_rule_violation",
            error.to_string(),
            correlation_id.to_string(),
        ),
        DomainError::LedgerOutOfBalance => ApiError::new(
            StatusCode::INTERNAL_SERVER_ERROR,
            "ledger_out_of_balance",
            error.to_string(),
            correlation_id.to_string(),
        ),
    }
}
