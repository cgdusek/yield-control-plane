#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum BudgetSpendMode {
    Enforce,
    Cleanup,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct CertificationAdmissionInput {
    pub budget_limit_cents: u64,
    pub actual_spend_cents: u64,
    pub pre_existing_queue_messages: u64,
    pub target_attempts: u64,
    pub duration_seconds: u64,
    pub queue_drain_capacity_per_second: u64,
    pub db_capacity_per_second: u64,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum CertificationAdmissionRejection {
    BudgetExceeded,
    DirtyQueue,
    InvalidDuration,
    QueueCapacityExceeded,
    DatabaseCapacityExceeded,
}

pub fn budget_allows(limit_cents: u64, actual_spend_cents: u64, mode: BudgetSpendMode) -> bool {
    mode == BudgetSpendMode::Cleanup || actual_spend_cents <= limit_cents
}

pub fn arrival_rate_per_second(target_attempts: u64, duration_seconds: u64) -> Option<u64> {
    if duration_seconds == 0 {
        return None;
    }
    let base = target_attempts / duration_seconds;
    let rounded = base + u64::from(!target_attempts.is_multiple_of(duration_seconds));
    Some(rounded.max(1))
}

pub fn admit_certification_campaign(
    input: CertificationAdmissionInput,
) -> Result<u64, CertificationAdmissionRejection> {
    if !budget_allows(
        input.budget_limit_cents,
        input.actual_spend_cents,
        BudgetSpendMode::Enforce,
    ) {
        return Err(CertificationAdmissionRejection::BudgetExceeded);
    }
    if input.pre_existing_queue_messages != 0 {
        return Err(CertificationAdmissionRejection::DirtyQueue);
    }
    let rate = arrival_rate_per_second(input.target_attempts, input.duration_seconds)
        .ok_or(CertificationAdmissionRejection::InvalidDuration)?;
    if rate > input.queue_drain_capacity_per_second {
        return Err(CertificationAdmissionRejection::QueueCapacityExceeded);
    }
    if rate > input.db_capacity_per_second {
        return Err(CertificationAdmissionRejection::DatabaseCapacityExceeded);
    }
    Ok(rate)
}

pub fn drain_after_one_tick(queue_messages: u64, drain_capacity: u64) -> u64 {
    queue_messages.saturating_sub(drain_capacity)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn bounded_campaign_is_admitted_with_rate_one() {
        let input = CertificationAdmissionInput {
            budget_limit_cents: 10_000,
            actual_spend_cents: 1_000,
            pre_existing_queue_messages: 0,
            target_attempts: 1_000,
            duration_seconds: 30 * 60,
            queue_drain_capacity_per_second: 1,
            db_capacity_per_second: 1,
        };

        assert_eq!(admit_certification_campaign(input), Ok(1));
    }

    #[test]
    fn dirty_queue_blocks_campaign_start() {
        let input = CertificationAdmissionInput {
            budget_limit_cents: 10_000,
            actual_spend_cents: 1_000,
            pre_existing_queue_messages: 1,
            target_attempts: 1_000,
            duration_seconds: 30 * 60,
            queue_drain_capacity_per_second: 1,
            db_capacity_per_second: 1,
        };

        assert_eq!(
            admit_certification_campaign(input),
            Err(CertificationAdmissionRejection::DirtyQueue)
        );
    }
}

#[cfg(kani)]
mod source_proofs {
    use super::*;

    fn bounded_input() -> CertificationAdmissionInput {
        CertificationAdmissionInput {
            budget_limit_cents: (kani::any::<u16>() as u64) + 1,
            actual_spend_cents: kani::any::<u16>() as u64,
            pre_existing_queue_messages: kani::any::<u8>() as u64,
            target_attempts: kani::any::<u16>() as u64,
            duration_seconds: (kani::any::<u8>() as u64) + 1,
            queue_drain_capacity_per_second: kani::any::<u8>() as u64,
            db_capacity_per_second: kani::any::<u8>() as u64,
        }
    }

    #[kani::proof]
    fn over_budget_blocks_enforced_campaign() {
        let limit = kani::any::<u16>() as u64;
        let actual = kani::any::<u16>() as u64;
        if actual > limit {
            assert!(!budget_allows(limit, actual, BudgetSpendMode::Enforce));
        }
    }

    #[kani::proof]
    fn cleanup_mode_allows_over_budget_evidence_collection() {
        let limit = kani::any::<u16>() as u64;
        let actual = kani::any::<u16>() as u64;
        assert!(budget_allows(limit, actual, BudgetSpendMode::Cleanup));
    }

    #[kani::proof]
    fn dirty_queue_blocks_campaign_start() {
        let mut input = bounded_input();
        input.pre_existing_queue_messages = (kani::any::<u8>() as u64) + 1;
        assert!(admit_certification_campaign(input).is_err());
    }

    #[kani::proof]
    fn dirty_queue_is_reported_when_budget_allows_start() {
        let mut input = bounded_input();
        input.actual_spend_cents = input.budget_limit_cents;
        input.pre_existing_queue_messages = (kani::any::<u8>() as u64) + 1;
        assert_eq!(
            admit_certification_campaign(input),
            Err(CertificationAdmissionRejection::DirtyQueue)
        );
    }

    #[kani::proof]
    fn zero_duration_blocks_campaign_start() {
        let mut input = bounded_input();
        input.duration_seconds = 0;
        if input.actual_spend_cents <= input.budget_limit_cents
            && input.pre_existing_queue_messages == 0
        {
            assert_eq!(
                admit_certification_campaign(input),
                Err(CertificationAdmissionRejection::InvalidDuration)
            );
        }
    }

    #[kani::proof]
    fn admitted_campaign_rate_is_within_queue_and_db_capacity() {
        let mut input = bounded_input();
        input.actual_spend_cents = input.budget_limit_cents;
        input.pre_existing_queue_messages = 0;
        let result = admit_certification_campaign(input);
        if let Ok(rate) = result {
            assert!(rate <= input.queue_drain_capacity_per_second);
            assert!(rate <= input.db_capacity_per_second);
        }
    }

    #[kani::proof]
    fn arrival_rate_is_positive_ceiling_for_bounded_inputs() {
        let target = kani::any::<u16>() as u64;
        let duration = (kani::any::<u8>() as u64) + 1;
        let rate = arrival_rate_per_second(target, duration).unwrap();
        assert!(rate >= 1);
        assert!(rate * duration >= target);
        if rate > 1 {
            assert!((rate - 1) * duration < target);
        }
    }

    #[kani::proof]
    fn drain_tick_never_increases_queue() {
        let queue = kani::any::<u16>() as u64;
        let capacity = kani::any::<u16>() as u64;
        assert!(drain_after_one_tick(queue, capacity) <= queue);
    }

    #[kani::proof]
    fn positive_capacity_eventually_drains_bounded_queue() {
        let mut queue = (kani::any::<u8>() % 16) as u64;
        let capacity = ((kani::any::<u8>() % 4) + 1) as u64;
        for _ in 0..16 {
            queue = drain_after_one_tick(queue, capacity);
        }
        assert_eq!(queue, 0);
    }
}
