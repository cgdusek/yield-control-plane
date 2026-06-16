use institutional_yield_domain::{transition, GuardContext, SweepCommand, SweepStatus};
use proptest::prelude::*;

fn status_by_index(index: usize) -> SweepStatus {
    SweepStatus::ALL[index % SweepStatus::ALL.len()]
}

fn command_by_index(index: usize) -> SweepCommand {
    SweepCommand::ALL[index % SweepCommand::ALL.len()]
}

proptest! {
    #[test]
    fn transitions_never_report_a_different_source(status_idx in 0usize..200, command_idx in 0usize..200) {
        let status = status_by_index(status_idx);
        let command = command_by_index(command_idx);
        let ctx = GuardContext::happy_path();
        if let Ok(outcome) = transition(status, command, &ctx) {
            prop_assert_eq!(outcome.from_status, status);
            prop_assert_eq!(outcome.command, command);
            prop_assert_ne!(outcome.from_status, outcome.to_status);
            prop_assert!(outcome.guard_results.iter().all(|guard| guard.passed));
        }
    }

    #[test]
    fn active_only_results_from_activate_after_reconciled(status_idx in 0usize..200, command_idx in 0usize..200) {
        let status = status_by_index(status_idx);
        let command = command_by_index(command_idx);
        let ctx = GuardContext::happy_path();
        if let Ok(outcome) = transition(status, command, &ctx) {
            if outcome.to_status == SweepStatus::Active {
                prop_assert_eq!(status, SweepStatus::Reconciled);
                prop_assert_eq!(command, SweepCommand::Activate);
            }
        }
    }

    #[test]
    fn cash_credited_only_results_from_confirmed_redemption(status_idx in 0usize..200, command_idx in 0usize..200) {
        let status = status_by_index(status_idx);
        let command = command_by_index(command_idx);
        let ctx = GuardContext::happy_path();
        if let Ok(outcome) = transition(status, command, &ctx) {
            if outcome.to_status == SweepStatus::CashCredited {
                prop_assert_eq!(status, SweepStatus::RedemptionConfirmed);
                prop_assert_eq!(command, SweepCommand::CreditCash);
            }
        }
    }
}
