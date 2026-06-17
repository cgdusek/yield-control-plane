use institutional_yield_domain::{
    transition, AbstractSweepState, Asset, GuardContext, SweepCommand, SweepStatus, TlaAction,
};

fn new_state() -> AbstractSweepState {
    AbstractSweepState::created(Asset::ProductAsset("YIELD_ASSET".to_string()))
        .expect("non-FIDD product asset")
}

fn drive(
    state: &mut AbstractSweepState,
    ctx: &GuardContext,
    commands: &[SweepCommand],
) -> Vec<TlaAction> {
    let mut actions = Vec::with_capacity(commands.len());
    for command in commands {
        let outcome =
            transition(state.status(), *command, ctx).expect("progress command should be enabled");
        let action = state.apply(&outcome).expect("progress trace refines TLA");
        assert_eq!(action, TlaAction::for_command(*command));
        actions.push(action);
    }
    state
        .assert_invariants()
        .expect("progress trace preserves abstract invariants");
    actions
}

#[test]
fn subscription_progress_reaches_active_under_happy_path_assumptions() {
    let ctx = GuardContext::happy_path();
    let mut state = new_state();
    let actions = drive(
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
    assert_eq!(actions.last(), Some(&TlaAction::Activate));
}

#[test]
fn redemption_progress_reaches_settled_under_confirmation_assumptions() {
    let ctx = GuardContext::happy_path();
    let mut state = new_state();
    drive(
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
            SweepCommand::SettleRedemption,
        ],
    );

    assert_eq!(state.status(), SweepStatus::Settled);
}

#[test]
fn exception_resolution_progress_reaches_exception_closed_if_operator_resolves() {
    let ctx = GuardContext::happy_path();
    let mut state = new_state();
    let actions = drive(
        &mut state,
        &ctx,
        &[SweepCommand::OpenException, SweepCommand::CloseException],
    );

    assert_eq!(state.status(), SweepStatus::ExceptionClosed);
    assert_eq!(
        actions,
        vec![TlaAction::OpenException, TlaAction::CloseException]
    );
}
