use institutional_yield_domain::{
    transition, DomainError, DomainEvent, GuardContext, SweepCommand, SweepStatus,
};
use serde_yaml::Value;
use std::{fs, path::Path};

#[test]
fn happy_path_reaches_active_only_after_reconciled() {
    let ctx = GuardContext::happy_path();
    let sequence = [
        (
            SweepStatus::Created,
            SweepCommand::CheckEligibility,
            SweepStatus::EligibilityChecked,
        ),
        (
            SweepStatus::EligibilityChecked,
            SweepCommand::CheckDisclosures,
            SweepStatus::DisclosureChecked,
        ),
        (
            SweepStatus::DisclosureChecked,
            SweepCommand::Approve,
            SweepStatus::Approved,
        ),
        (
            SweepStatus::Approved,
            SweepCommand::LockCash,
            SweepStatus::CashLocked,
        ),
        (
            SweepStatus::CashLocked,
            SweepCommand::SubmitSubscription,
            SweepStatus::SubscriptionSubmitted,
        ),
        (
            SweepStatus::SubscriptionSubmitted,
            SweepCommand::ConfirmTransferAgent,
            SweepStatus::TransferAgentConfirmed,
        ),
        (
            SweepStatus::TransferAgentConfirmed,
            SweepCommand::BookPosition,
            SweepStatus::PositionBooked,
        ),
        (
            SweepStatus::PositionBooked,
            SweepCommand::Reconcile,
            SweepStatus::Reconciled,
        ),
        (
            SweepStatus::Reconciled,
            SweepCommand::Activate,
            SweepStatus::Active,
        ),
    ];

    for (from, command, to) in sequence {
        let outcome = transition(from, command, &ctx).expect("valid happy-path transition");
        assert_eq!(outcome.from_status, from);
        assert_eq!(outcome.to_status, to);
    }
}

#[test]
fn active_cannot_be_reached_before_reconciled() {
    let ctx = GuardContext::happy_path();
    let error = transition(SweepStatus::PositionBooked, SweepCommand::Activate, &ctx)
        .expect_err("activate before reconciled must fail");
    assert!(matches!(error, DomainError::InvalidTransition { .. }));
}

#[test]
fn invalid_transition_is_rejected() {
    let ctx = GuardContext::happy_path();
    let error = transition(SweepStatus::Created, SweepCommand::BookPosition, &ctx)
        .expect_err("book position from Created must fail");
    assert!(matches!(error, DomainError::InvalidTransition { .. }));
}

#[test]
fn failed_guard_is_rejected() {
    let mut ctx = GuardContext::happy_path();
    ctx.transfer_agent_confirmation_present = false;
    let error = transition(
        SweepStatus::SubscriptionSubmitted,
        SweepCommand::ConfirmTransferAgent,
        &ctx,
    )
    .expect_err("confirmation guard must fail");
    assert_eq!(
        error,
        DomainError::GuardFailed {
            guard: "transfer_agent_confirmation_present".to_string()
        }
    );
}

#[test]
fn position_booking_emits_position_booked_event() {
    let ctx = GuardContext::happy_path();
    let outcome = transition(
        SweepStatus::TransferAgentConfirmed,
        SweepCommand::BookPosition,
        &ctx,
    )
    .expect("position booking should succeed with confirmation");
    assert_eq!(
        outcome.emitted_events,
        vec![DomainEvent::SweepPositionBooked]
    );
}

#[test]
fn rust_statuses_match_yaml_machine() {
    let manifest_dir = Path::new(env!("CARGO_MANIFEST_DIR"));
    let machine_path = manifest_dir.join("../../spec/domain/sweep_order.machine.yaml");
    let contents = fs::read_to_string(machine_path).expect("state machine YAML readable");
    let yaml: Value = serde_yaml::from_str(&contents).expect("state machine YAML parses");
    let yaml_statuses = yaml["statuses"]
        .as_sequence()
        .expect("statuses sequence")
        .iter()
        .map(|value| value.as_str().expect("status is string").to_string())
        .collect::<Vec<_>>();
    let rust_statuses = SweepStatus::ALL
        .iter()
        .map(|status| status.to_string())
        .collect::<Vec<_>>();
    assert_eq!(rust_statuses, yaml_statuses);
}

#[test]
fn cancel_is_limited_to_pre_submission_states() {
    let ctx = GuardContext::happy_path();
    assert!(transition(SweepStatus::Approved, SweepCommand::Cancel, &ctx).is_ok());
    let error = transition(SweepStatus::CashLocked, SweepCommand::Cancel, &ctx)
        .expect_err("cash-locked orders cannot be directly cancelled");
    assert!(matches!(error, DomainError::InvalidTransition { .. }));
}
