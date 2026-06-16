use crate::error::ApiError;
use axum::http::{HeaderMap, StatusCode};

#[derive(Debug, Clone)]
pub struct RequiredHeaders {
    pub idempotency_key: String,
    pub correlation_id: String,
}

pub fn require_write_headers(headers: &HeaderMap) -> Result<RequiredHeaders, ApiError> {
    let correlation_id =
        header_value(headers, "Correlation-Id").unwrap_or_else(|| "missing".to_string());
    let idempotency_key = header_value(headers, "Idempotency-Key").ok_or_else(|| {
        ApiError::new(
            StatusCode::BAD_REQUEST,
            "missing_idempotency_key",
            "write requests require Idempotency-Key",
            correlation_id.clone(),
        )
    })?;
    let correlation_id = header_value(headers, "Correlation-Id").ok_or_else(|| {
        ApiError::new(
            StatusCode::BAD_REQUEST,
            "missing_correlation_id",
            "write requests require Correlation-Id",
            "missing",
        )
    })?;
    Ok(RequiredHeaders {
        idempotency_key,
        correlation_id,
    })
}

fn header_value(headers: &HeaderMap, name: &'static str) -> Option<String> {
    headers
        .get(name)
        .and_then(|value| value.to_str().ok())
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(ToOwned::to_owned)
}
