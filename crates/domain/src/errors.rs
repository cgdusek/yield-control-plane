use thiserror::Error;

pub type DomainResult<T> = Result<T, DomainError>;

#[derive(Debug, Error, Clone, PartialEq, Eq)]
pub enum DomainError {
    #[error("invalid transition from {from} using {command}")]
    InvalidTransition { from: String, command: String },
    #[error("guard failed: {guard}")]
    GuardFailed { guard: String },
    #[error("asset {asset} cannot be used as a yield-bearing source")]
    YieldOnCashRailForbidden { asset: String },
    #[error("position booking requires transfer-agent confirmation")]
    MissingTransferAgentConfirmation,
    #[error("ledger entries must balance per asset")]
    LedgerOutOfBalance,
    #[error("money asset mismatch")]
    AssetMismatch,
    #[error("amount must be non-negative")]
    NegativeAmount,
    #[error("parse error: {0}")]
    Parse(String),
}
