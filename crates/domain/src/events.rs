use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use uuid::Uuid;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum DomainEvent {
    SweepOrderCreated,
    SweepEligibilityChecked,
    SweepDisclosuresChecked,
    SweepOrderApproved,
    SweepCashLocked,
    SweepSubscriptionSubmitted,
    SweepTransferAgentConfirmed,
    SweepChainMirrorObserved,
    SweepPositionBooked,
    SweepReconciled,
    SweepActive,
    RedemptionRequested,
    RedemptionSubmitted,
    RedemptionConfirmed,
    RedemptionCashCredited,
    ReconciliationBreakOpened,
    ReconciliationBreakResolved,
    AuditEventRecorded,
}

impl DomainEvent {
    pub fn event_type(&self) -> &'static str {
        match self {
            DomainEvent::SweepOrderCreated => "sweep.order.created.v1",
            DomainEvent::SweepEligibilityChecked => "sweep.eligibility.checked.v1",
            DomainEvent::SweepDisclosuresChecked => "sweep.disclosures.checked.v1",
            DomainEvent::SweepOrderApproved => "sweep.order.approved.v1",
            DomainEvent::SweepCashLocked => "sweep.cash.locked.v1",
            DomainEvent::SweepSubscriptionSubmitted => "sweep.subscription.submitted.v1",
            DomainEvent::SweepTransferAgentConfirmed => "sweep.transfer_agent.confirmed.v1",
            DomainEvent::SweepChainMirrorObserved => "sweep.chain_mirror.observed.v1",
            DomainEvent::SweepPositionBooked => "sweep.position.booked.v1",
            DomainEvent::SweepReconciled => "sweep.reconciled.v1",
            DomainEvent::SweepActive => "sweep.active.v1",
            DomainEvent::RedemptionRequested => "redemption.requested.v1",
            DomainEvent::RedemptionSubmitted => "redemption.submitted.v1",
            DomainEvent::RedemptionConfirmed => "redemption.confirmed.v1",
            DomainEvent::RedemptionCashCredited => "redemption.cash_credited.v1",
            DomainEvent::ReconciliationBreakOpened => "reconciliation.break.opened.v1",
            DomainEvent::ReconciliationBreakResolved => "reconciliation.break.resolved.v1",
            DomainEvent::AuditEventRecorded => "audit.event.recorded.v1",
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EventEnvelope {
    pub event_id: Uuid,
    pub event_type: String,
    pub schema_version: i32,
    pub aggregate_id: Uuid,
    pub correlation_id: String,
    pub causation_id: Option<Uuid>,
    pub idempotency_key_hash: Option<String>,
    pub occurred_at: DateTime<Utc>,
    pub payload: Value,
}

impl EventEnvelope {
    pub fn new(
        event: DomainEvent,
        aggregate_id: Uuid,
        correlation_id: impl Into<String>,
        causation_id: Option<Uuid>,
        idempotency_key_hash: Option<String>,
        payload: Value,
    ) -> Self {
        Self {
            event_id: Uuid::new_v4(),
            event_type: event.event_type().to_string(),
            schema_version: 1,
            aggregate_id,
            correlation_id: correlation_id.into(),
            causation_id,
            idempotency_key_hash,
            occurred_at: Utc::now(),
            payload,
        }
    }
}
