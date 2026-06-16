use crate::{DomainError, DomainEvent, DomainResult};
use serde::{Deserialize, Serialize};
use std::{fmt, str::FromStr};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum SweepStatus {
    Created,
    EligibilityChecked,
    DisclosureChecked,
    Approved,
    CashLocked,
    SubscriptionSubmitted,
    TransferAgentConfirmed,
    ChainMirrorObserved,
    PositionBooked,
    Reconciled,
    Active,
    RedemptionRequested,
    SharesReserved,
    RedemptionSubmitted,
    RedemptionConfirmed,
    CashCredited,
    Settled,
    ExceptionOpen,
    ExceptionClosed,
    Cancelled,
}

impl SweepStatus {
    pub const ALL: [SweepStatus; 20] = [
        SweepStatus::Created,
        SweepStatus::EligibilityChecked,
        SweepStatus::DisclosureChecked,
        SweepStatus::Approved,
        SweepStatus::CashLocked,
        SweepStatus::SubscriptionSubmitted,
        SweepStatus::TransferAgentConfirmed,
        SweepStatus::ChainMirrorObserved,
        SweepStatus::PositionBooked,
        SweepStatus::Reconciled,
        SweepStatus::Active,
        SweepStatus::RedemptionRequested,
        SweepStatus::SharesReserved,
        SweepStatus::RedemptionSubmitted,
        SweepStatus::RedemptionConfirmed,
        SweepStatus::CashCredited,
        SweepStatus::Settled,
        SweepStatus::ExceptionOpen,
        SweepStatus::ExceptionClosed,
        SweepStatus::Cancelled,
    ];

    pub fn as_str(self) -> &'static str {
        match self {
            SweepStatus::Created => "Created",
            SweepStatus::EligibilityChecked => "EligibilityChecked",
            SweepStatus::DisclosureChecked => "DisclosureChecked",
            SweepStatus::Approved => "Approved",
            SweepStatus::CashLocked => "CashLocked",
            SweepStatus::SubscriptionSubmitted => "SubscriptionSubmitted",
            SweepStatus::TransferAgentConfirmed => "TransferAgentConfirmed",
            SweepStatus::ChainMirrorObserved => "ChainMirrorObserved",
            SweepStatus::PositionBooked => "PositionBooked",
            SweepStatus::Reconciled => "Reconciled",
            SweepStatus::Active => "Active",
            SweepStatus::RedemptionRequested => "RedemptionRequested",
            SweepStatus::SharesReserved => "SharesReserved",
            SweepStatus::RedemptionSubmitted => "RedemptionSubmitted",
            SweepStatus::RedemptionConfirmed => "RedemptionConfirmed",
            SweepStatus::CashCredited => "CashCredited",
            SweepStatus::Settled => "Settled",
            SweepStatus::ExceptionOpen => "ExceptionOpen",
            SweepStatus::ExceptionClosed => "ExceptionClosed",
            SweepStatus::Cancelled => "Cancelled",
        }
    }
}

impl fmt::Display for SweepStatus {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(self.as_str())
    }
}

impl FromStr for SweepStatus {
    type Err = DomainError;

    fn from_str(value: &str) -> Result<Self, Self::Err> {
        SweepStatus::ALL
            .iter()
            .copied()
            .find(|status| status.as_str() == value)
            .ok_or_else(|| DomainError::Parse(format!("unknown sweep status {value}")))
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum SweepCommand {
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
    CloseException,
    Cancel,
}

impl SweepCommand {
    pub const ALL: [SweepCommand; 19] = [
        SweepCommand::CheckEligibility,
        SweepCommand::CheckDisclosures,
        SweepCommand::Approve,
        SweepCommand::LockCash,
        SweepCommand::SubmitSubscription,
        SweepCommand::ConfirmTransferAgent,
        SweepCommand::ObserveChainMirror,
        SweepCommand::BookPosition,
        SweepCommand::Reconcile,
        SweepCommand::Activate,
        SweepCommand::RequestRedemption,
        SweepCommand::ReserveShares,
        SweepCommand::SubmitRedemption,
        SweepCommand::ConfirmRedemption,
        SweepCommand::CreditCash,
        SweepCommand::SettleRedemption,
        SweepCommand::OpenException,
        SweepCommand::CloseException,
        SweepCommand::Cancel,
    ];

    pub fn as_str(self) -> &'static str {
        match self {
            SweepCommand::CheckEligibility => "CheckEligibility",
            SweepCommand::CheckDisclosures => "CheckDisclosures",
            SweepCommand::Approve => "Approve",
            SweepCommand::LockCash => "LockCash",
            SweepCommand::SubmitSubscription => "SubmitSubscription",
            SweepCommand::ConfirmTransferAgent => "ConfirmTransferAgent",
            SweepCommand::ObserveChainMirror => "ObserveChainMirror",
            SweepCommand::BookPosition => "BookPosition",
            SweepCommand::Reconcile => "Reconcile",
            SweepCommand::Activate => "Activate",
            SweepCommand::RequestRedemption => "RequestRedemption",
            SweepCommand::ReserveShares => "ReserveShares",
            SweepCommand::SubmitRedemption => "SubmitRedemption",
            SweepCommand::ConfirmRedemption => "ConfirmRedemption",
            SweepCommand::CreditCash => "CreditCash",
            SweepCommand::SettleRedemption => "SettleRedemption",
            SweepCommand::OpenException => "OpenException",
            SweepCommand::CloseException => "CloseException",
            SweepCommand::Cancel => "Cancel",
        }
    }
}

impl fmt::Display for SweepCommand {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(self.as_str())
    }
}

impl FromStr for SweepCommand {
    type Err = DomainError;

    fn from_str(value: &str) -> Result<Self, Self::Err> {
        SweepCommand::ALL
            .iter()
            .copied()
            .find(|command| command.as_str() == value)
            .ok_or_else(|| DomainError::Parse(format!("unknown sweep command {value}")))
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct GuardContext {
    pub eligible_account: bool,
    pub disclosures_current: bool,
    pub authorized_approver: bool,
    pub cash_available: bool,
    pub cash_locked: bool,
    pub transfer_agent_confirmation_present: bool,
    pub chain_mirror_required: bool,
    pub chain_mirror_observed: bool,
    pub reconciliation_matched: bool,
    pub redeemable_position: bool,
    pub shares_available: bool,
    pub shares_reserved: bool,
    pub redemption_confirmation_present: bool,
    pub cash_credited: bool,
    pub exception_reason_present: bool,
    pub exception_resolved: bool,
    pub cancellable: bool,
}

impl GuardContext {
    pub fn happy_path() -> Self {
        Self {
            eligible_account: true,
            disclosures_current: true,
            authorized_approver: true,
            cash_available: true,
            cash_locked: true,
            transfer_agent_confirmation_present: true,
            chain_mirror_required: false,
            chain_mirror_observed: false,
            reconciliation_matched: true,
            redeemable_position: true,
            shares_available: true,
            shares_reserved: true,
            redemption_confirmation_present: true,
            cash_credited: true,
            exception_reason_present: true,
            exception_resolved: true,
            cancellable: true,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct GuardResult {
    pub name: String,
    pub passed: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct TransitionOutcome {
    pub from_status: SweepStatus,
    pub to_status: SweepStatus,
    pub command: SweepCommand,
    pub emitted_events: Vec<DomainEvent>,
    pub guard_results: Vec<GuardResult>,
}

pub fn transition(
    current: SweepStatus,
    command: SweepCommand,
    ctx: &GuardContext,
) -> DomainResult<TransitionOutcome> {
    let definition = transition_definition(current, command, ctx).ok_or_else(|| {
        DomainError::InvalidTransition {
            from: current.to_string(),
            command: command.to_string(),
        }
    })?;
    let guard_results = definition
        .guards
        .iter()
        .map(|guard| GuardResult {
            name: (*guard).to_string(),
            passed: guard_passed(guard, ctx),
        })
        .collect::<Vec<_>>();

    if let Some(failed) = guard_results.iter().find(|result| !result.passed) {
        return Err(DomainError::GuardFailed {
            guard: failed.name.clone(),
        });
    }

    Ok(TransitionOutcome {
        from_status: current,
        to_status: definition.to,
        command,
        emitted_events: definition.events,
        guard_results,
    })
}

struct TransitionDefinition {
    to: SweepStatus,
    guards: &'static [&'static str],
    events: Vec<DomainEvent>,
}

fn transition_definition(
    current: SweepStatus,
    command: SweepCommand,
    ctx: &GuardContext,
) -> Option<TransitionDefinition> {
    use DomainEvent as Event;
    use SweepCommand as Command;
    use SweepStatus as Status;

    let definition = match (current, command) {
        (Status::Created, Command::CheckEligibility) => TransitionDefinition {
            to: Status::EligibilityChecked,
            guards: &["eligible_account"],
            events: vec![Event::SweepEligibilityChecked],
        },
        (Status::EligibilityChecked, Command::CheckDisclosures) => TransitionDefinition {
            to: Status::DisclosureChecked,
            guards: &["disclosures_current"],
            events: vec![Event::SweepDisclosuresChecked],
        },
        (Status::DisclosureChecked, Command::Approve) => TransitionDefinition {
            to: Status::Approved,
            guards: &["authorized_approver"],
            events: vec![Event::SweepOrderApproved],
        },
        (Status::Approved, Command::LockCash) => TransitionDefinition {
            to: Status::CashLocked,
            guards: &["cash_available"],
            events: vec![Event::SweepCashLocked],
        },
        (Status::CashLocked, Command::SubmitSubscription) => TransitionDefinition {
            to: Status::SubscriptionSubmitted,
            guards: &["cash_locked"],
            events: vec![Event::SweepSubscriptionSubmitted],
        },
        (Status::SubscriptionSubmitted, Command::ConfirmTransferAgent) => TransitionDefinition {
            to: Status::TransferAgentConfirmed,
            guards: &["transfer_agent_confirmation_present"],
            events: vec![Event::SweepTransferAgentConfirmed],
        },
        (Status::TransferAgentConfirmed, Command::ObserveChainMirror)
            if ctx.chain_mirror_required =>
        {
            TransitionDefinition {
                to: Status::ChainMirrorObserved,
                guards: &["chain_mirror_required", "chain_mirror_observed"],
                events: vec![Event::SweepChainMirrorObserved],
            }
        }
        (Status::TransferAgentConfirmed, Command::BookPosition) if !ctx.chain_mirror_required => {
            TransitionDefinition {
                to: Status::PositionBooked,
                guards: &[
                    "transfer_agent_confirmation_present",
                    "chain_mirror_not_required",
                ],
                events: vec![Event::SweepPositionBooked],
            }
        }
        (Status::ChainMirrorObserved, Command::BookPosition) => TransitionDefinition {
            to: Status::PositionBooked,
            guards: &[
                "transfer_agent_confirmation_present",
                "chain_mirror_observed",
            ],
            events: vec![Event::SweepPositionBooked],
        },
        (Status::PositionBooked, Command::Reconcile) => TransitionDefinition {
            to: Status::Reconciled,
            guards: &["reconciliation_matched"],
            events: vec![Event::SweepReconciled],
        },
        (Status::Reconciled, Command::Activate) => TransitionDefinition {
            to: Status::Active,
            guards: &["reconciled"],
            events: vec![Event::SweepActive],
        },
        (Status::Active, Command::RequestRedemption) => TransitionDefinition {
            to: Status::RedemptionRequested,
            guards: &["redeemable_position"],
            events: vec![Event::RedemptionRequested],
        },
        (Status::RedemptionRequested, Command::ReserveShares) => TransitionDefinition {
            to: Status::SharesReserved,
            guards: &["shares_available"],
            events: vec![],
        },
        (Status::SharesReserved, Command::SubmitRedemption) => TransitionDefinition {
            to: Status::RedemptionSubmitted,
            guards: &["shares_reserved"],
            events: vec![Event::RedemptionSubmitted],
        },
        (Status::RedemptionSubmitted, Command::ConfirmRedemption) => TransitionDefinition {
            to: Status::RedemptionConfirmed,
            guards: &["redemption_confirmation_present"],
            events: vec![Event::RedemptionConfirmed],
        },
        (Status::RedemptionConfirmed, Command::CreditCash) => TransitionDefinition {
            to: Status::CashCredited,
            guards: &["redemption_confirmation_present"],
            events: vec![Event::RedemptionCashCredited],
        },
        (Status::CashCredited, Command::SettleRedemption) => TransitionDefinition {
            to: Status::Settled,
            guards: &["cash_credited"],
            events: vec![],
        },
        (
            Status::Created
            | Status::EligibilityChecked
            | Status::DisclosureChecked
            | Status::Approved,
            Command::Cancel,
        ) => TransitionDefinition {
            to: Status::Cancelled,
            guards: &["cancellable"],
            events: vec![],
        },
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
        ) => TransitionDefinition {
            to: Status::ExceptionOpen,
            guards: &["exception_reason_present"],
            events: vec![Event::ReconciliationBreakOpened],
        },
        (Status::ExceptionOpen, Command::CloseException) => TransitionDefinition {
            to: Status::ExceptionClosed,
            guards: &["exception_resolved"],
            events: vec![Event::ReconciliationBreakResolved],
        },
        _ => return None,
    };
    Some(definition)
}

fn guard_passed(guard: &str, ctx: &GuardContext) -> bool {
    match guard {
        "eligible_account" => ctx.eligible_account,
        "disclosures_current" => ctx.disclosures_current,
        "authorized_approver" => ctx.authorized_approver,
        "cash_available" => ctx.cash_available,
        "cash_locked" => ctx.cash_locked,
        "transfer_agent_confirmation_present" => ctx.transfer_agent_confirmation_present,
        "chain_mirror_required" => ctx.chain_mirror_required,
        "chain_mirror_not_required" => !ctx.chain_mirror_required,
        "chain_mirror_observed" => ctx.chain_mirror_observed,
        "reconciliation_matched" => ctx.reconciliation_matched,
        "reconciled" => true,
        "redeemable_position" => ctx.redeemable_position,
        "shares_available" => ctx.shares_available,
        "shares_reserved" => ctx.shares_reserved,
        "redemption_confirmation_present" => ctx.redemption_confirmation_present,
        "cash_credited" => ctx.cash_credited,
        "exception_reason_present" => ctx.exception_reason_present,
        "exception_resolved" => ctx.exception_resolved,
        "cancellable" => ctx.cancellable,
        _ => false,
    }
}

pub fn is_valid_transition(
    current: SweepStatus,
    command: SweepCommand,
    ctx: &GuardContext,
) -> bool {
    transition(current, command, ctx).is_ok()
}
