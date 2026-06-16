use institutional_yield_domain::{
    invariants::ensure_yield_source_allowed, ledger::validate_position_booking_confirmation, Asset,
    DebitCredit, DomainError, LedgerEntry, LedgerEntryKind,
};
use rust_decimal_macros::dec;
use uuid::Uuid;

fn entry(asset: Asset, amount: rust_decimal::Decimal, side: DebitCredit) -> LedgerEntry {
    LedgerEntry {
        entry_id: Uuid::new_v4(),
        account_id: Uuid::new_v4(),
        order_id: Some(Uuid::new_v4()),
        asset,
        amount,
        side,
        ledger_account: "test".to_string(),
        kind: LedgerEntryKind::Adjustment,
    }
}

#[test]
fn ledger_balances_per_asset() {
    let entries = vec![
        entry(Asset::USD, dec!(10.00), DebitCredit::Debit),
        entry(Asset::USD, dec!(10.00), DebitCredit::Credit),
    ];
    institutional_yield_domain::validate_ledger_balances(&entries).expect("balanced ledger");
}

#[test]
fn ledger_rejects_out_of_balance_entries() {
    let entries = vec![
        entry(Asset::USD, dec!(10.00), DebitCredit::Debit),
        entry(Asset::USD, dec!(9.99), DebitCredit::Credit),
    ];
    assert_eq!(
        institutional_yield_domain::validate_ledger_balances(&entries),
        Err(DomainError::LedgerOutOfBalance)
    );
}

#[test]
fn fidd_cannot_be_yield_bearing_source() {
    assert_eq!(
        ensure_yield_source_allowed(&Asset::FIDD),
        Err(DomainError::YieldOnCashRailForbidden {
            asset: "FIDD".to_string()
        })
    );
    ensure_yield_source_allowed(&Asset::ProductAsset("FYOXX".to_string()))
        .expect("fund shares may be modeled as yield-bearing positions");
}

#[test]
fn position_booking_requires_transfer_agent_confirmation() {
    assert_eq!(
        validate_position_booking_confirmation(None),
        Err(DomainError::MissingTransferAgentConfirmation)
    );
    assert_eq!(
        validate_position_booking_confirmation(Some("   ")),
        Err(DomainError::MissingTransferAgentConfirmation)
    );
    validate_position_booking_confirmation(Some("ta-confirmed-1")).expect("confirmation accepted");
}
