use crate::{Asset, DomainError, DomainResult};
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use uuid::Uuid;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum DebitCredit {
    Debit,
    Credit,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum LedgerEntryKind {
    CashLock,
    PositionBooking,
    CashCredit,
    Income,
    Adjustment,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LedgerEntry {
    pub entry_id: Uuid,
    pub account_id: Uuid,
    pub order_id: Option<Uuid>,
    pub asset: Asset,
    #[serde(with = "rust_decimal::serde::str")]
    pub amount: Decimal,
    pub side: DebitCredit,
    pub ledger_account: String,
    pub kind: LedgerEntryKind,
}

pub fn validate_ledger_balances(entries: &[LedgerEntry]) -> DomainResult<()> {
    let mut balances: HashMap<Asset, Decimal> = HashMap::new();
    for entry in entries {
        if entry.amount.is_sign_negative() {
            return Err(DomainError::NegativeAmount);
        }
        let signed = match entry.side {
            DebitCredit::Debit => entry.amount,
            DebitCredit::Credit => -entry.amount,
        };
        *balances.entry(entry.asset.clone()).or_default() += signed;
    }

    if balances.values().all(|amount| amount.is_zero()) {
        Ok(())
    } else {
        Err(DomainError::LedgerOutOfBalance)
    }
}

pub fn validate_position_booking_confirmation(confirmation_ref: Option<&str>) -> DomainResult<()> {
    match confirmation_ref
        .map(str::trim)
        .filter(|value| !value.is_empty())
    {
        Some(_) => Ok(()),
        None => Err(DomainError::MissingTransferAgentConfirmation),
    }
}
