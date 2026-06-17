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
    let guard_results = definition.guards.results(ctx);

    if let Some(failed) = guard_results.iter().find(|result| !result.passed) {
        return Err(DomainError::GuardFailed {
            guard: failed.name.clone(),
        });
    }

    Ok(TransitionOutcome {
        from_status: current,
        to_status: definition.to,
        command,
        emitted_events: definition.events.to_vec(),
        guard_results,
    })
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Guard {
    EligibleAccount,
    DisclosuresCurrent,
    AuthorizedApprover,
    CashAvailable,
    CashLocked,
    TransferAgentConfirmationPresent,
    ChainMirrorRequired,
    ChainMirrorNotRequired,
    ChainMirrorObserved,
    ReconciliationMatched,
    Reconciled,
    RedeemablePosition,
    SharesAvailable,
    SharesReserved,
    RedemptionConfirmationPresent,
    CashCredited,
    ExceptionReasonPresent,
    ExceptionResolved,
    Cancellable,
}

impl Guard {
    fn name(self) -> &'static str {
        match self {
            Guard::EligibleAccount => "eligible_account",
            Guard::DisclosuresCurrent => "disclosures_current",
            Guard::AuthorizedApprover => "authorized_approver",
            Guard::CashAvailable => "cash_available",
            Guard::CashLocked => "cash_locked",
            Guard::TransferAgentConfirmationPresent => "transfer_agent_confirmation_present",
            Guard::ChainMirrorRequired => "chain_mirror_required",
            Guard::ChainMirrorNotRequired => "chain_mirror_not_required",
            Guard::ChainMirrorObserved => "chain_mirror_observed",
            Guard::ReconciliationMatched => "reconciliation_matched",
            Guard::Reconciled => "reconciled",
            Guard::RedeemablePosition => "redeemable_position",
            Guard::SharesAvailable => "shares_available",
            Guard::SharesReserved => "shares_reserved",
            Guard::RedemptionConfirmationPresent => "redemption_confirmation_present",
            Guard::CashCredited => "cash_credited",
            Guard::ExceptionReasonPresent => "exception_reason_present",
            Guard::ExceptionResolved => "exception_resolved",
            Guard::Cancellable => "cancellable",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum GuardSet {
    One(Guard),
    Two(Guard, Guard),
}

impl GuardSet {
    fn results(self, ctx: &GuardContext) -> Vec<GuardResult> {
        match self {
            GuardSet::One(first) => vec![guard_result(first, ctx)],
            GuardSet::Two(first, second) => {
                vec![guard_result(first, ctx), guard_result(second, ctx)]
            }
        }
    }

    #[cfg(kani)]
    fn satisfied(self, ctx: &GuardContext) -> bool {
        match self {
            GuardSet::One(first) => guard_passed(first, ctx),
            GuardSet::Two(first, second) => guard_passed(first, ctx) && guard_passed(second, ctx),
        }
    }
}

fn guard_result(guard: Guard, ctx: &GuardContext) -> GuardResult {
    GuardResult {
        name: guard.name().to_string(),
        passed: guard_passed(guard, ctx),
    }
}

struct TransitionDefinition {
    to: SweepStatus,
    guards: GuardSet,
    events: &'static [DomainEvent],
}

#[cfg(kani)]
fn accepted_transition(
    current: SweepStatus,
    command: SweepCommand,
    ctx: &GuardContext,
) -> Option<SweepStatus> {
    let definition = transition_definition(current, command, ctx)?;
    if definition.guards.satisfied(ctx) {
        Some(definition.to)
    } else {
        None
    }
}

fn transition_definition(
    current: SweepStatus,
    command: SweepCommand,
    ctx: &GuardContext,
) -> Option<TransitionDefinition> {
    use DomainEvent as Event;
    use Guard as G;
    use GuardSet as GS;
    use SweepCommand as Command;
    use SweepStatus as Status;

    let definition = match (current, command) {
        (Status::Created, Command::CheckEligibility) => TransitionDefinition {
            to: Status::EligibilityChecked,
            guards: GS::One(G::EligibleAccount),
            events: &[Event::SweepEligibilityChecked],
        },
        (Status::EligibilityChecked, Command::CheckDisclosures) => TransitionDefinition {
            to: Status::DisclosureChecked,
            guards: GS::One(G::DisclosuresCurrent),
            events: &[Event::SweepDisclosuresChecked],
        },
        (Status::DisclosureChecked, Command::Approve) => TransitionDefinition {
            to: Status::Approved,
            guards: GS::One(G::AuthorizedApprover),
            events: &[Event::SweepOrderApproved],
        },
        (Status::Approved, Command::LockCash) => TransitionDefinition {
            to: Status::CashLocked,
            guards: GS::One(G::CashAvailable),
            events: &[Event::SweepCashLocked],
        },
        (Status::CashLocked, Command::SubmitSubscription) => TransitionDefinition {
            to: Status::SubscriptionSubmitted,
            guards: GS::One(G::CashLocked),
            events: &[Event::SweepSubscriptionSubmitted],
        },
        (Status::SubscriptionSubmitted, Command::ConfirmTransferAgent) => TransitionDefinition {
            to: Status::TransferAgentConfirmed,
            guards: GS::One(G::TransferAgentConfirmationPresent),
            events: &[Event::SweepTransferAgentConfirmed],
        },
        (Status::TransferAgentConfirmed, Command::ObserveChainMirror)
            if ctx.chain_mirror_required =>
        {
            TransitionDefinition {
                to: Status::ChainMirrorObserved,
                guards: GS::Two(G::ChainMirrorRequired, G::ChainMirrorObserved),
                events: &[Event::SweepChainMirrorObserved],
            }
        }
        (Status::TransferAgentConfirmed, Command::BookPosition) if !ctx.chain_mirror_required => {
            TransitionDefinition {
                to: Status::PositionBooked,
                guards: GS::Two(
                    G::TransferAgentConfirmationPresent,
                    G::ChainMirrorNotRequired,
                ),
                events: &[Event::SweepPositionBooked],
            }
        }
        (Status::ChainMirrorObserved, Command::BookPosition) => TransitionDefinition {
            to: Status::PositionBooked,
            guards: GS::Two(G::TransferAgentConfirmationPresent, G::ChainMirrorObserved),
            events: &[Event::SweepPositionBooked],
        },
        (Status::PositionBooked, Command::Reconcile) => TransitionDefinition {
            to: Status::Reconciled,
            guards: GS::One(G::ReconciliationMatched),
            events: &[Event::SweepReconciled],
        },
        (Status::Reconciled, Command::Activate) => TransitionDefinition {
            to: Status::Active,
            guards: GS::One(G::Reconciled),
            events: &[Event::SweepActive],
        },
        (Status::Active, Command::RequestRedemption) => TransitionDefinition {
            to: Status::RedemptionRequested,
            guards: GS::One(G::RedeemablePosition),
            events: &[Event::RedemptionRequested],
        },
        (Status::RedemptionRequested, Command::ReserveShares) => TransitionDefinition {
            to: Status::SharesReserved,
            guards: GS::One(G::SharesAvailable),
            events: &[],
        },
        (Status::SharesReserved, Command::SubmitRedemption) => TransitionDefinition {
            to: Status::RedemptionSubmitted,
            guards: GS::One(G::SharesReserved),
            events: &[Event::RedemptionSubmitted],
        },
        (Status::RedemptionSubmitted, Command::ConfirmRedemption) => TransitionDefinition {
            to: Status::RedemptionConfirmed,
            guards: GS::One(G::RedemptionConfirmationPresent),
            events: &[Event::RedemptionConfirmed],
        },
        (Status::RedemptionConfirmed, Command::CreditCash) => TransitionDefinition {
            to: Status::CashCredited,
            guards: GS::One(G::RedemptionConfirmationPresent),
            events: &[Event::RedemptionCashCredited],
        },
        (Status::CashCredited, Command::SettleRedemption) => TransitionDefinition {
            to: Status::Settled,
            guards: GS::One(G::CashCredited),
            events: &[],
        },
        (
            Status::Created
            | Status::EligibilityChecked
            | Status::DisclosureChecked
            | Status::Approved,
            Command::Cancel,
        ) => TransitionDefinition {
            to: Status::Cancelled,
            guards: GS::One(G::Cancellable),
            events: &[],
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
            guards: GS::One(G::ExceptionReasonPresent),
            events: &[Event::ReconciliationBreakOpened],
        },
        (Status::ExceptionOpen, Command::CloseException) => TransitionDefinition {
            to: Status::ExceptionClosed,
            guards: GS::One(G::ExceptionResolved),
            events: &[Event::ReconciliationBreakResolved],
        },
        _ => return None,
    };
    Some(definition)
}

fn guard_passed(guard: Guard, ctx: &GuardContext) -> bool {
    match guard {
        Guard::EligibleAccount => ctx.eligible_account,
        Guard::DisclosuresCurrent => ctx.disclosures_current,
        Guard::AuthorizedApprover => ctx.authorized_approver,
        Guard::CashAvailable => ctx.cash_available,
        Guard::CashLocked => ctx.cash_locked,
        Guard::TransferAgentConfirmationPresent => ctx.transfer_agent_confirmation_present,
        Guard::ChainMirrorRequired => ctx.chain_mirror_required,
        Guard::ChainMirrorNotRequired => !ctx.chain_mirror_required,
        Guard::ChainMirrorObserved => ctx.chain_mirror_observed,
        Guard::ReconciliationMatched => ctx.reconciliation_matched,
        Guard::Reconciled => true,
        Guard::RedeemablePosition => ctx.redeemable_position,
        Guard::SharesAvailable => ctx.shares_available,
        Guard::SharesReserved => ctx.shares_reserved,
        Guard::RedemptionConfirmationPresent => ctx.redemption_confirmation_present,
        Guard::CashCredited => ctx.cash_credited,
        Guard::ExceptionReasonPresent => ctx.exception_reason_present,
        Guard::ExceptionResolved => ctx.exception_resolved,
        Guard::Cancellable => ctx.cancellable,
    }
}

pub fn is_valid_transition(
    current: SweepStatus,
    command: SweepCommand,
    ctx: &GuardContext,
) -> bool {
    transition(current, command, ctx).is_ok()
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

    fn any_guard_context() -> GuardContext {
        GuardContext {
            eligible_account: kani::any(),
            disclosures_current: kani::any(),
            authorized_approver: kani::any(),
            cash_available: kani::any(),
            cash_locked: kani::any(),
            transfer_agent_confirmation_present: kani::any(),
            chain_mirror_required: kani::any(),
            chain_mirror_observed: kani::any(),
            reconciliation_matched: kani::any(),
            redeemable_position: kani::any(),
            shares_available: kani::any(),
            shares_reserved: kani::any(),
            redemption_confirmation_present: kani::any(),
            cash_credited: kani::any(),
            exception_reason_present: kani::any(),
            exception_resolved: kani::any(),
            cancellable: kani::any(),
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
    fn accepted_transitions_never_stutter_and_preserve_source_command() {
        let status = any_status();
        let command = any_command();
        let ctx = any_guard_context();

        if let Some(to) = accepted_transition(status, command, &ctx) {
            assert!(to != status);
            assert!(transition_definition(status, command, &ctx).is_some());
        }
    }

    #[kani::proof]
    fn active_can_only_be_reached_by_activate_from_reconciled() {
        let status = any_status();
        let command = any_command();
        let ctx = any_guard_context();

        if let Some(SweepStatus::Active) = accepted_transition(status, command, &ctx) {
            assert!(status == SweepStatus::Reconciled);
            assert!(command == SweepCommand::Activate);
        }
    }

    #[kani::proof]
    fn cash_credited_can_only_be_reached_after_redemption_confirmation() {
        let status = any_status();
        let command = any_command();
        let ctx = any_guard_context();

        if let Some(SweepStatus::CashCredited) = accepted_transition(status, command, &ctx) {
            assert!(status == SweepStatus::RedemptionConfirmed);
            assert!(command == SweepCommand::CreditCash);
            assert!(ctx.redemption_confirmation_present);
        }
    }

    #[kani::proof]
    fn position_booked_requires_transfer_agent_confirmation() {
        let status = any_status();
        let command = any_command();
        let ctx = any_guard_context();

        if let Some(SweepStatus::PositionBooked) = accepted_transition(status, command, &ctx) {
            assert!(
                status == SweepStatus::TransferAgentConfirmed
                    || status == SweepStatus::ChainMirrorObserved
            );
            assert!(command == SweepCommand::BookPosition);
            assert!(ctx.transfer_agent_confirmation_present);
            if status == SweepStatus::TransferAgentConfirmed {
                assert!(!ctx.chain_mirror_required);
            }
            if status == SweepStatus::ChainMirrorObserved {
                assert!(ctx.chain_mirror_observed);
            }
        }
    }

    #[kani::proof]
    fn cancellation_is_limited_to_pre_submission_states() {
        let status = any_status();
        let command = any_command();
        let ctx = any_guard_context();

        if let Some(SweepStatus::Cancelled) = accepted_transition(status, command, &ctx) {
            assert!(command == SweepCommand::Cancel);
            assert!(pre_submission_status(status));
            assert!(ctx.cancellable);
        }
    }

    #[kani::proof]
    fn exception_open_excludes_terminal_statuses() {
        let status = any_status();
        let command = any_command();
        let ctx = any_guard_context();

        if let Some(SweepStatus::ExceptionOpen) = accepted_transition(status, command, &ctx) {
            assert!(command == SweepCommand::OpenException);
            assert!(exception_openable_status(status));
            assert!(ctx.exception_reason_present);
        }
    }
}
