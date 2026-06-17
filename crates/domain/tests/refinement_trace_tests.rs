use institutional_yield_domain::{
    transition, AbstractSweepState, Asset, GuardContext, RefinementError, SweepCommand,
    SweepStatus, TlaAction,
};
use proptest::prelude::*;
use proptest::test_runner::TestCaseError;
use serde::Deserialize;
use std::{
    collections::{BTreeMap, HashSet},
    path::PathBuf,
    str::FromStr,
};

#[derive(Debug, Deserialize)]
struct RefinementMapping {
    commands: BTreeMap<String, MappingRecord>,
}

#[derive(Debug, Deserialize)]
struct MappingRecord {
    tla_action: String,
    from: Vec<String>,
    to: String,
}

fn command_by_index(index: usize) -> SweepCommand {
    SweepCommand::ALL[index % SweepCommand::ALL.len()]
}

fn mapping_path() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../..")
        .join("spec/refinement/rust_tla_mapping.yaml")
}

fn load_mapping() -> RefinementMapping {
    let source = std::fs::read_to_string(mapping_path()).expect("refinement mapping file");
    serde_yaml::from_str(&source).expect("valid refinement mapping yaml")
}

fn parse_status(value: &str) -> SweepStatus {
    SweepStatus::from_str(value).expect("mapped status should be a Rust SweepStatus")
}

fn parse_command(value: &str) -> SweepCommand {
    SweepCommand::from_str(value).expect("mapped command should be a Rust SweepCommand")
}

fn parse_tla_action(value: &str) -> TlaAction {
    TlaAction::DOMAIN_COMMAND_ACTIONS
        .iter()
        .copied()
        .chain([TlaAction::CreateOrder])
        .find(|action| action.as_str() == value)
        .expect("mapped action should be a Rust TlaAction")
}

fn refinement_contexts() -> [GuardContext; 2] {
    let happy = GuardContext::happy_path();
    let mut chain_mirror = GuardContext::happy_path();
    chain_mirror.chain_mirror_required = true;
    chain_mirror.chain_mirror_observed = true;
    [happy, chain_mirror]
}

fn apply_commands(
    state: &mut AbstractSweepState,
    ctx: &GuardContext,
    commands: &[SweepCommand],
) -> Vec<TlaAction> {
    let mut actions = Vec::with_capacity(commands.len());
    for command in commands {
        let outcome =
            transition(state.status(), *command, ctx).expect("trace command should be valid");
        let action = state.apply(&outcome).expect("trace should refine TLA");
        assert_eq!(action, TlaAction::for_command(*command));
        actions.push(action);
    }
    actions
}

#[test]
fn every_sweep_command_has_a_tla_action_mapping() {
    let mapped_actions = SweepCommand::ALL
        .iter()
        .map(|command| TlaAction::for_command(*command).as_str())
        .collect::<Vec<_>>();
    let command_names = SweepCommand::ALL
        .iter()
        .map(|command| command.as_str())
        .collect::<Vec<_>>();

    assert_eq!(mapped_actions, command_names);
    assert_eq!(
        TlaAction::DOMAIN_COMMAND_ACTIONS.len(),
        SweepCommand::ALL.len()
    );
}

#[test]
fn declared_mapping_paths_are_accepted_and_project_to_tla_actions() {
    let mapping = load_mapping();
    let contexts = refinement_contexts();
    let expected_paths = mapping
        .commands
        .values()
        .map(|record| record.from.len())
        .sum::<usize>();
    let mut checked_paths = 0usize;

    for (command_name, record) in mapping.commands {
        let command = parse_command(&command_name);
        let expected_action = parse_tla_action(&record.tla_action);
        let expected_to = parse_status(&record.to);

        for from_name in record.from {
            let from = parse_status(&from_name);
            let outcome = contexts
                .iter()
                .find_map(|ctx| transition(from, command, ctx).ok())
                .unwrap_or_else(|| {
                    panic!(
                        "{from} --{command}--> {} is declared but not accepted",
                        record.to
                    )
                });

            assert_eq!(outcome.to_status, expected_to);
            assert_eq!(TlaAction::for_outcome(&outcome), Ok(expected_action));
            assert_eq!(expected_action, TlaAction::for_command(command));
            checked_paths += 1;
        }
    }

    assert_eq!(checked_paths, expected_paths);
}

#[test]
fn every_supported_transition_has_mapping_evidence() {
    let mapping = load_mapping();
    let declared = mapping
        .commands
        .iter()
        .flat_map(|(command_name, record)| {
            let command = parse_command(command_name);
            let to = parse_status(&record.to);
            record
                .from
                .iter()
                .map(move |from| (parse_status(from), command, to))
        })
        .collect::<HashSet<_>>();

    let contexts = refinement_contexts();
    let mut observed = HashSet::new();
    for ctx in &contexts {
        for status in SweepStatus::ALL {
            for command in SweepCommand::ALL {
                if let Ok(outcome) = transition(status, command, ctx) {
                    let triple = (outcome.from_status, outcome.command, outcome.to_status);
                    assert!(
                        declared.contains(&triple),
                        "accepted Rust transition is missing from rust_tla_mapping.yaml: {} --{}--> {}",
                        outcome.from_status,
                        outcome.command,
                        outcome.to_status
                    );
                    assert_eq!(
                        TlaAction::for_outcome(&outcome),
                        Ok(TlaAction::for_command(command))
                    );
                    observed.insert(triple);
                }
            }
        }
    }

    assert_eq!(observed, declared);
}

#[test]
fn happy_path_trace_refines_tla_history_invariants() {
    let ctx = GuardContext::happy_path();
    let mut state = AbstractSweepState::created(Asset::ProductAsset("YIELD_ASSET".to_string()))
        .expect("non-FIDD product asset");
    let actions = apply_commands(
        &mut state,
        &ctx,
        &[
            SweepCommand::CheckEligibility,
            SweepCommand::CheckDisclosures,
            SweepCommand::Approve,
            SweepCommand::LockCash,
            SweepCommand::SubmitSubscription,
            SweepCommand::ConfirmTransferAgent,
            SweepCommand::BookPosition,
            SweepCommand::Reconcile,
            SweepCommand::Activate,
        ],
    );

    assert_eq!(state.status(), SweepStatus::Active);
    assert!(state.seen_statuses().contains(&SweepStatus::Reconciled));
    assert_eq!(state.ledger_debit(), state.ledger_credit());
    assert_eq!(state.ledger_debit(), 2);
    assert_eq!(actions.last(), Some(&TlaAction::Activate));
}

#[test]
fn redemption_trace_refines_cash_credit_history_invariant() {
    let ctx = GuardContext::happy_path();
    let mut state = AbstractSweepState::created(Asset::ProductAsset("YIELD_ASSET".to_string()))
        .expect("non-FIDD product asset");
    apply_commands(
        &mut state,
        &ctx,
        &[
            SweepCommand::CheckEligibility,
            SweepCommand::CheckDisclosures,
            SweepCommand::Approve,
            SweepCommand::LockCash,
            SweepCommand::SubmitSubscription,
            SweepCommand::ConfirmTransferAgent,
            SweepCommand::BookPosition,
            SweepCommand::Reconcile,
            SweepCommand::Activate,
            SweepCommand::RequestRedemption,
            SweepCommand::ReserveShares,
            SweepCommand::SubmitRedemption,
            SweepCommand::ConfirmRedemption,
            SweepCommand::CreditCash,
        ],
    );

    assert_eq!(state.status(), SweepStatus::CashCredited);
    assert!(state
        .seen_statuses()
        .contains(&SweepStatus::RedemptionConfirmed));
    assert_eq!(state.ledger_debit(), state.ledger_credit());
    assert_eq!(state.ledger_debit(), 3);
}

#[test]
fn chain_mirror_branch_refines_position_booking_invariant() {
    let mut ctx = GuardContext::happy_path();
    ctx.chain_mirror_required = true;
    ctx.chain_mirror_observed = true;
    let mut state = AbstractSweepState::created(Asset::ProductAsset("YIELD_ASSET".to_string()))
        .expect("non-FIDD product asset");
    apply_commands(
        &mut state,
        &ctx,
        &[
            SweepCommand::CheckEligibility,
            SweepCommand::CheckDisclosures,
            SweepCommand::Approve,
            SweepCommand::LockCash,
            SweepCommand::SubmitSubscription,
            SweepCommand::ConfirmTransferAgent,
            SweepCommand::ObserveChainMirror,
            SweepCommand::BookPosition,
        ],
    );

    assert_eq!(state.status(), SweepStatus::PositionBooked);
    assert!(state
        .seen_statuses()
        .contains(&SweepStatus::ChainMirrorObserved));
    assert_eq!(state.ledger_debit(), state.ledger_credit());
}

#[test]
fn cancel_and_exception_closure_are_modeled_tla_actions() {
    let ctx = GuardContext::happy_path();
    let mut cancelled = AbstractSweepState::created(Asset::ProductAsset("YIELD_ASSET".to_string()))
        .expect("non-FIDD product asset");
    let cancel_outcome =
        transition(cancelled.status(), SweepCommand::Cancel, &ctx).expect("cancel is valid");
    assert_eq!(
        cancelled.apply(&cancel_outcome).expect("cancel refines"),
        TlaAction::Cancel
    );
    assert_eq!(cancelled.status(), SweepStatus::Cancelled);

    let mut exception = AbstractSweepState::created(Asset::ProductAsset("YIELD_ASSET".to_string()))
        .expect("non-FIDD product asset");
    let open_outcome = transition(exception.status(), SweepCommand::OpenException, &ctx)
        .expect("open exception is valid");
    assert_eq!(
        exception.apply(&open_outcome).expect("open refines"),
        TlaAction::OpenException
    );
    let close_outcome = transition(exception.status(), SweepCommand::CloseException, &ctx)
        .expect("close exception is valid");
    assert_eq!(
        exception.apply(&close_outcome).expect("close refines"),
        TlaAction::CloseException
    );
    assert_eq!(exception.status(), SweepStatus::ExceptionClosed);
}

#[test]
fn fidd_cannot_seed_the_abstract_yield_source() {
    assert_eq!(
        AbstractSweepState::created(Asset::FIDD).expect_err("FIDD is not a yield source"),
        RefinementError::FiddYieldSource
    );
}

proptest! {
    #[test]
    fn accepted_random_command_prefixes_refine_tla_actions(command_indexes in proptest::collection::vec(0usize..200, 0..80)) {
        let ctx = GuardContext::happy_path();
        let mut state =
            AbstractSweepState::created(Asset::ProductAsset("YIELD_ASSET".to_string()))
                .expect("non-FIDD product asset");

        for index in command_indexes {
            let command = command_by_index(index);
            if let Ok(outcome) = transition(state.status(), command, &ctx) {
                let prior_assets = state.ledger_entry_assets().clone();
                let action = state
                    .apply(&outcome)
                    .map_err(|err| TestCaseError::fail(format!("refinement failed: {err}")))?;
                prop_assert_eq!(action, TlaAction::for_command(command));
                prop_assert!(prior_assets.is_subset(state.ledger_entry_assets()));
                prop_assert_eq!(state.ledger_debit(), state.ledger_credit());
                state
                    .assert_invariants()
                    .map_err(|err| TestCaseError::fail(format!("invariant failed: {err}")))?;
            }
        }
    }
}
