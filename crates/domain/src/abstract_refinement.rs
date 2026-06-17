use crate::{Asset, SweepCommand, SweepStatus, TransitionOutcome};
use std::collections::HashSet;
use thiserror::Error;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum TlaAction {
    CreateOrder,
    CheckEligibility,
    CheckDisclosures,
    Approve,
    LockCash,
    SubmitSubscription,
    ConfirmTransferAgent,
    ObserveChainMirror,
    BookPosition,
    Reconcile,
    Activate,
    RequestRedemption,
    ReserveShares,
    SubmitRedemption,
    ConfirmRedemption,
    CreditCash,
    SettleRedemption,
    OpenException,
    Cancel,
    CloseException,
}

impl TlaAction {
    pub const DOMAIN_COMMAND_ACTIONS: [TlaAction; 19] = [
        TlaAction::CheckEligibility,
        TlaAction::CheckDisclosures,
        TlaAction::Approve,
        TlaAction::LockCash,
        TlaAction::SubmitSubscription,
        TlaAction::ConfirmTransferAgent,
        TlaAction::ObserveChainMirror,
        TlaAction::BookPosition,
        TlaAction::Reconcile,
        TlaAction::Activate,
        TlaAction::RequestRedemption,
        TlaAction::ReserveShares,
        TlaAction::SubmitRedemption,
        TlaAction::ConfirmRedemption,
        TlaAction::CreditCash,
        TlaAction::SettleRedemption,
        TlaAction::OpenException,
        TlaAction::CloseException,
        TlaAction::Cancel,
    ];

    pub fn as_str(self) -> &'static str {
        match self {
            TlaAction::CreateOrder => "CreateOrder",
            TlaAction::CheckEligibility => "CheckEligibility",
            TlaAction::CheckDisclosures => "CheckDisclosures",
            TlaAction::Approve => "Approve",
            TlaAction::LockCash => "LockCash",
            TlaAction::SubmitSubscription => "SubmitSubscription",
            TlaAction::ConfirmTransferAgent => "ConfirmTransferAgent",
            TlaAction::ObserveChainMirror => "ObserveChainMirror",
            TlaAction::BookPosition => "BookPosition",
            TlaAction::Reconcile => "Reconcile",
            TlaAction::Activate => "Activate",
            TlaAction::RequestRedemption => "RequestRedemption",
            TlaAction::ReserveShares => "ReserveShares",
            TlaAction::SubmitRedemption => "SubmitRedemption",
            TlaAction::ConfirmRedemption => "ConfirmRedemption",
            TlaAction::CreditCash => "CreditCash",
            TlaAction::SettleRedemption => "SettleRedemption",
            TlaAction::OpenException => "OpenException",
            TlaAction::Cancel => "Cancel",
            TlaAction::CloseException => "CloseException",
        }
    }

    pub fn for_command(command: SweepCommand) -> Self {
        match command {
            SweepCommand::CheckEligibility => TlaAction::CheckEligibility,
            SweepCommand::CheckDisclosures => TlaAction::CheckDisclosures,
            SweepCommand::Approve => TlaAction::Approve,
            SweepCommand::LockCash => TlaAction::LockCash,
            SweepCommand::SubmitSubscription => TlaAction::SubmitSubscription,
            SweepCommand::ConfirmTransferAgent => TlaAction::ConfirmTransferAgent,
            SweepCommand::ObserveChainMirror => TlaAction::ObserveChainMirror,
            SweepCommand::BookPosition => TlaAction::BookPosition,
            SweepCommand::Reconcile => TlaAction::Reconcile,
            SweepCommand::Activate => TlaAction::Activate,
            SweepCommand::RequestRedemption => TlaAction::RequestRedemption,
            SweepCommand::ReserveShares => TlaAction::ReserveShares,
            SweepCommand::SubmitRedemption => TlaAction::SubmitRedemption,
            SweepCommand::ConfirmRedemption => TlaAction::ConfirmRedemption,
            SweepCommand::CreditCash => TlaAction::CreditCash,
            SweepCommand::SettleRedemption => TlaAction::SettleRedemption,
            SweepCommand::OpenException => TlaAction::OpenException,
            SweepCommand::CloseException => TlaAction::CloseException,
            SweepCommand::Cancel => TlaAction::Cancel,
        }
    }

    pub fn for_outcome(outcome: &TransitionOutcome) -> RefinementResult<Self> {
        let action = TlaAction::for_parts(outcome.from_status, outcome.command, outcome.to_status)
            .ok_or(RefinementError::UnmappedTransition {
                from: outcome.from_status,
                command: outcome.command,
                to: outcome.to_status,
            })?;

        if action != TlaAction::for_command(outcome.command) {
            return Err(RefinementError::CommandActionMismatch {
                command: outcome.command,
                action,
            });
        }

        Ok(action)
    }

    fn for_parts(
        from_status: SweepStatus,
        command: SweepCommand,
        to_status: SweepStatus,
    ) -> Option<Self> {
        use SweepCommand as Command;
        use SweepStatus as Status;

        Some(match (from_status, command, to_status) {
            (Status::Created, Command::CheckEligibility, Status::EligibilityChecked) => {
                TlaAction::CheckEligibility
            }
            (Status::EligibilityChecked, Command::CheckDisclosures, Status::DisclosureChecked) => {
                TlaAction::CheckDisclosures
            }
            (Status::DisclosureChecked, Command::Approve, Status::Approved) => TlaAction::Approve,
            (Status::Approved, Command::LockCash, Status::CashLocked) => TlaAction::LockCash,
            (Status::CashLocked, Command::SubmitSubscription, Status::SubscriptionSubmitted) => {
                TlaAction::SubmitSubscription
            }
            (
                Status::SubscriptionSubmitted,
                Command::ConfirmTransferAgent,
                Status::TransferAgentConfirmed,
            ) => TlaAction::ConfirmTransferAgent,
            (
                Status::TransferAgentConfirmed,
                Command::ObserveChainMirror,
                Status::ChainMirrorObserved,
            ) => TlaAction::ObserveChainMirror,
            (
                Status::TransferAgentConfirmed | Status::ChainMirrorObserved,
                Command::BookPosition,
                Status::PositionBooked,
            ) => TlaAction::BookPosition,
            (Status::PositionBooked, Command::Reconcile, Status::Reconciled) => {
                TlaAction::Reconcile
            }
            (Status::Reconciled, Command::Activate, Status::Active) => TlaAction::Activate,
            (Status::Active, Command::RequestRedemption, Status::RedemptionRequested) => {
                TlaAction::RequestRedemption
            }
            (Status::RedemptionRequested, Command::ReserveShares, Status::SharesReserved) => {
                TlaAction::ReserveShares
            }
            (Status::SharesReserved, Command::SubmitRedemption, Status::RedemptionSubmitted) => {
                TlaAction::SubmitRedemption
            }
            (
                Status::RedemptionSubmitted,
                Command::ConfirmRedemption,
                Status::RedemptionConfirmed,
            ) => TlaAction::ConfirmRedemption,
            (Status::RedemptionConfirmed, Command::CreditCash, Status::CashCredited) => {
                TlaAction::CreditCash
            }
            (Status::CashCredited, Command::SettleRedemption, Status::Settled) => {
                TlaAction::SettleRedemption
            }
            (
                Status::Created
                | Status::EligibilityChecked
                | Status::DisclosureChecked
                | Status::Approved,
                Command::Cancel,
                Status::Cancelled,
            ) => TlaAction::Cancel,
            (
                Status::Created
                | Status::EligibilityChecked
                | Status::DisclosureChecked
                | Status::Approved
                | Status::CashLocked
                | Status::SubscriptionSubmitted
                | Status::TransferAgentConfirmed
                | Status::ChainMirrorObserved
                | Status::PositionBooked
                | Status::Reconciled
                | Status::Active
                | Status::RedemptionRequested
                | Status::SharesReserved
                | Status::RedemptionSubmitted
                | Status::RedemptionConfirmed
                | Status::CashCredited,
                Command::OpenException,
                Status::ExceptionOpen,
            ) => TlaAction::OpenException,
            (Status::ExceptionOpen, Command::CloseException, Status::ExceptionClosed) => {
                TlaAction::CloseException
            }
            _ => return None,
        })
    }
}

#[derive(Debug, Error, PartialEq, Eq)]
pub enum RefinementError {
    #[error("FIDD cannot be modeled as the yield source")]
    FiddYieldSource,
    #[error("expected abstract status {expected}, got transition from {actual}")]
    SourceStatusMismatch {
        expected: SweepStatus,
        actual: SweepStatus,
    },
    #[error("transition {from} --{command}--> {to} has no TLA action mapping")]
    UnmappedTransition {
        from: SweepStatus,
        command: SweepCommand,
        to: SweepStatus,
    },
    #[error("command {command} mapped to unexpected TLA action {action:?}")]
    CommandActionMismatch {
        command: SweepCommand,
        action: TlaAction,
    },
    #[error("position booking requires prior transfer-agent confirmation")]
    MissingTransferAgentConfirmation,
    #[error("crediting cash requires prior redemption confirmation")]
    MissingRedemptionConfirmation,
    #[error("current status {0} is not present in abstract history")]
    CurrentStatusMissingFromHistory(SweepStatus),
    #[error("Active status requires Reconciled in abstract history")]
    ActiveWithoutReconciledHistory,
    #[error("CashCredited status requires RedemptionConfirmed in abstract history")]
    CashCreditedWithoutRedemptionHistory,
    #[error("abstract ledger is out of balance: debit={debit}, credit={credit}")]
    LedgerOutOfBalance { debit: u64, credit: u64 },
}

pub type RefinementResult<T> = Result<T, RefinementError>;

#[derive(Debug, Clone)]
pub struct AbstractSweepState {
    status: SweepStatus,
    product_asset: Asset,
    seen_statuses: HashSet<SweepStatus>,
    position_booked: bool,
    transfer_agent_confirmation_seen: bool,
    redemption_confirmation_seen: bool,
    ledger_debit: u64,
    ledger_credit: u64,
    ledger_entries: HashSet<String>,
}

impl AbstractSweepState {
    pub fn created(product_asset: Asset) -> RefinementResult<Self> {
        if !product_asset.is_yield_bearing_allowed() {
            return Err(RefinementError::FiddYieldSource);
        }

        let mut seen_statuses = HashSet::new();
        seen_statuses.insert(SweepStatus::Created);
        Ok(Self {
            status: SweepStatus::Created,
            product_asset,
            seen_statuses,
            position_booked: false,
            transfer_agent_confirmation_seen: false,
            redemption_confirmation_seen: false,
            ledger_debit: 0,
            ledger_credit: 0,
            ledger_entries: HashSet::new(),
        })
    }

    pub fn status(&self) -> SweepStatus {
        self.status
    }

    pub fn seen_statuses(&self) -> &HashSet<SweepStatus> {
        &self.seen_statuses
    }

    pub fn ledger_debit(&self) -> u64 {
        self.ledger_debit
    }

    pub fn ledger_credit(&self) -> u64 {
        self.ledger_credit
    }

    pub fn ledger_entry_assets(&self) -> &HashSet<String> {
        &self.ledger_entries
    }

    pub fn apply(&mut self, outcome: &TransitionOutcome) -> RefinementResult<TlaAction> {
        if outcome.from_status != self.status {
            return Err(RefinementError::SourceStatusMismatch {
                expected: self.status,
                actual: outcome.from_status,
            });
        }

        let action = TlaAction::for_outcome(outcome)?;
        match action {
            TlaAction::Activate if !self.seen_statuses.contains(&SweepStatus::Reconciled) => {
                return Err(RefinementError::ActiveWithoutReconciledHistory);
            }
            TlaAction::BookPosition if !self.transfer_agent_confirmation_seen => {
                return Err(RefinementError::MissingTransferAgentConfirmation);
            }
            TlaAction::CreditCash if !self.redemption_confirmation_seen => {
                return Err(RefinementError::MissingRedemptionConfirmation);
            }
            _ => {}
        }

        self.status = outcome.to_status;
        self.seen_statuses.insert(outcome.to_status);

        match action {
            TlaAction::LockCash | TlaAction::BookPosition | TlaAction::CreditCash => {
                self.add_balanced_ledger_effect();
            }
            TlaAction::ConfirmTransferAgent => {
                self.transfer_agent_confirmation_seen = true;
            }
            TlaAction::ConfirmRedemption => {
                self.redemption_confirmation_seen = true;
            }
            _ => {}
        }

        self.assert_invariants()?;
        Ok(action)
    }

    pub fn assert_invariants(&self) -> RefinementResult<()> {
        if !self.product_asset.is_yield_bearing_allowed() {
            return Err(RefinementError::FiddYieldSource);
        }
        if !self.seen_statuses.contains(&self.status) {
            return Err(RefinementError::CurrentStatusMissingFromHistory(
                self.status,
            ));
        }
        if self.position_booked && !self.transfer_agent_confirmation_seen {
            return Err(RefinementError::MissingTransferAgentConfirmation);
        }
        if self.status == SweepStatus::Active
            && !self.seen_statuses.contains(&SweepStatus::Reconciled)
        {
            return Err(RefinementError::ActiveWithoutReconciledHistory);
        }
        if self.status == SweepStatus::CashCredited
            && !self
                .seen_statuses
                .contains(&SweepStatus::RedemptionConfirmed)
        {
            return Err(RefinementError::CashCreditedWithoutRedemptionHistory);
        }
        if self.ledger_debit != self.ledger_credit {
            return Err(RefinementError::LedgerOutOfBalance {
                debit: self.ledger_debit,
                credit: self.ledger_credit,
            });
        }
        Ok(())
    }

    fn add_balanced_ledger_effect(&mut self) {
        self.ledger_debit += 1;
        self.ledger_credit += 1;
        self.ledger_entries
            .insert(self.product_asset.symbol().to_string());
        if self.status == SweepStatus::PositionBooked {
            self.position_booked = true;
        }
    }
}

#[cfg(kani)]
mod source_proofs {
    use super::*;

    fn any_status() -> SweepStatus {
        match kani::any::<u8>() % SweepStatus::ALL.len() as u8 {
            0 => SweepStatus::Created,
            1 => SweepStatus::EligibilityChecked,
            2 => SweepStatus::DisclosureChecked,
            3 => SweepStatus::Approved,
            4 => SweepStatus::CashLocked,
            5 => SweepStatus::SubscriptionSubmitted,
            6 => SweepStatus::TransferAgentConfirmed,
            7 => SweepStatus::ChainMirrorObserved,
            8 => SweepStatus::PositionBooked,
            9 => SweepStatus::Reconciled,
            10 => SweepStatus::Active,
            11 => SweepStatus::RedemptionRequested,
            12 => SweepStatus::SharesReserved,
            13 => SweepStatus::RedemptionSubmitted,
            14 => SweepStatus::RedemptionConfirmed,
            15 => SweepStatus::CashCredited,
            16 => SweepStatus::Settled,
            17 => SweepStatus::ExceptionOpen,
            18 => SweepStatus::ExceptionClosed,
            _ => SweepStatus::Cancelled,
        }
    }

    fn any_command() -> SweepCommand {
        match kani::any::<u8>() % SweepCommand::ALL.len() as u8 {
            0 => SweepCommand::CheckEligibility,
            1 => SweepCommand::CheckDisclosures,
            2 => SweepCommand::Approve,
            3 => SweepCommand::LockCash,
            4 => SweepCommand::SubmitSubscription,
            5 => SweepCommand::ConfirmTransferAgent,
            6 => SweepCommand::ObserveChainMirror,
            7 => SweepCommand::BookPosition,
            8 => SweepCommand::Reconcile,
            9 => SweepCommand::Activate,
            10 => SweepCommand::RequestRedemption,
            11 => SweepCommand::ReserveShares,
            12 => SweepCommand::SubmitRedemption,
            13 => SweepCommand::ConfirmRedemption,
            14 => SweepCommand::CreditCash,
            15 => SweepCommand::SettleRedemption,
            16 => SweepCommand::OpenException,
            17 => SweepCommand::CloseException,
            _ => SweepCommand::Cancel,
        }
    }

    fn pre_submission_status(status: SweepStatus) -> bool {
        matches!(
            status,
            SweepStatus::Created
                | SweepStatus::EligibilityChecked
                | SweepStatus::DisclosureChecked
                | SweepStatus::Approved
        )
    }

    fn exception_openable_status(status: SweepStatus) -> bool {
        matches!(
            status,
            SweepStatus::Created
                | SweepStatus::EligibilityChecked
                | SweepStatus::DisclosureChecked
                | SweepStatus::Approved
                | SweepStatus::CashLocked
                | SweepStatus::SubscriptionSubmitted
                | SweepStatus::TransferAgentConfirmed
                | SweepStatus::ChainMirrorObserved
                | SweepStatus::PositionBooked
                | SweepStatus::Reconciled
                | SweepStatus::Active
                | SweepStatus::RedemptionRequested
                | SweepStatus::SharesReserved
                | SweepStatus::RedemptionSubmitted
                | SweepStatus::RedemptionConfirmed
                | SweepStatus::CashCredited
        )
    }

    #[kani::proof]
    fn mapped_parts_always_match_command_action() {
        let from = any_status();
        let command = any_command();
        let to = any_status();

        if let Some(action) = TlaAction::for_parts(from, command, to) {
            assert!(action == TlaAction::for_command(command));
        }
    }

    #[kani::proof]
    fn mapped_activate_only_from_reconciled_to_active() {
        let from = any_status();
        let command = any_command();
        let to = any_status();

        if let Some(TlaAction::Activate) = TlaAction::for_parts(from, command, to) {
            assert!(from == SweepStatus::Reconciled);
            assert!(command == SweepCommand::Activate);
            assert!(to == SweepStatus::Active);
        }
    }

    #[kani::proof]
    fn mapped_book_position_has_transfer_agent_source_status() {
        let from = any_status();
        let command = any_command();
        let to = any_status();

        if let Some(TlaAction::BookPosition) = TlaAction::for_parts(from, command, to) {
            assert!(
                from == SweepStatus::TransferAgentConfirmed
                    || from == SweepStatus::ChainMirrorObserved
            );
            assert!(command == SweepCommand::BookPosition);
            assert!(to == SweepStatus::PositionBooked);
        }
    }

    #[kani::proof]
    fn mapped_credit_cash_only_from_redemption_confirmed() {
        let from = any_status();
        let command = any_command();
        let to = any_status();

        if let Some(TlaAction::CreditCash) = TlaAction::for_parts(from, command, to) {
            assert!(from == SweepStatus::RedemptionConfirmed);
            assert!(command == SweepCommand::CreditCash);
            assert!(to == SweepStatus::CashCredited);
        }
    }

    #[kani::proof]
    fn mapped_cancel_is_limited_to_pre_submission() {
        let from = any_status();
        let command = any_command();
        let to = any_status();

        if let Some(TlaAction::Cancel) = TlaAction::for_parts(from, command, to) {
            assert!(pre_submission_status(from));
            assert!(command == SweepCommand::Cancel);
            assert!(to == SweepStatus::Cancelled);
        }
    }

    #[kani::proof]
    fn mapped_open_exception_excludes_terminal_statuses() {
        let from = any_status();
        let command = any_command();
        let to = any_status();

        if let Some(TlaAction::OpenException) = TlaAction::for_parts(from, command, to) {
            assert!(exception_openable_status(from));
            assert!(command == SweepCommand::OpenException);
            assert!(to == SweepStatus::ExceptionOpen);
        }
    }
}
