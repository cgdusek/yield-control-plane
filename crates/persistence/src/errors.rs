use thiserror::Error;
use uuid::Uuid;

pub type PersistenceResult<T> = Result<T, PersistenceError>;

#[derive(Debug, Error)]
pub enum PersistenceError {
    #[error(transparent)]
    Sqlx(#[from] sqlx::Error),
    #[error(transparent)]
    Migrate(#[from] sqlx::migrate::MigrateError),
    #[error(transparent)]
    Domain(#[from] institutional_yield_domain::DomainError),
    #[error("record not found: {0}")]
    NotFound(String),
    #[error("idempotency request hash mismatch for scope {scope}")]
    IdempotencyConflict { scope: String },
    #[error("order {0} has no transfer-agent confirmation")]
    MissingConfirmation(Uuid),
    #[error("serialization error: {0}")]
    Serialization(#[from] serde_json::Error),
    #[error("parse error: {0}")]
    Parse(String),
}
