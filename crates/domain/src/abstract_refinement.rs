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
        use SweepCommand as Command;
        use SweepStatus as Status;

        let action = match (outcome.from_status, outcome.command, outcome.to_status) {
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
            _ => {
                return Err(RefinementError::UnmappedTransition {
                    from: outcome.from_status,
                    command: outcome.command,
                    to: outcome.to_status,
                });
            }
        };

        if action != TlaAction::for_command(outcome.command) {
            return Err(RefinementError::CommandActionMismatch {
                command: outcome.command,
                action,
            });
        }

        Ok(action)
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
