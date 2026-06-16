pub use institutional_yield_domain::EventEnvelope;

pub fn event_matches(envelope: &EventEnvelope, accepted: &[&str]) -> bool {
    accepted.contains(&envelope.event_type.as_str())
}
