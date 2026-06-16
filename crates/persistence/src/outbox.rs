use crate::{OutboxEventRecord, PersistenceResult};
use institutional_yield_domain::EventEnvelope;
use sqlx::{PgPool, Postgres, Transaction};
use uuid::Uuid;

pub async fn insert_outbox_event(
    tx: &mut Transaction<'_, Postgres>,
    envelope: &EventEnvelope,
) -> PersistenceResult<()> {
    let payload = serde_json::to_value(envelope)?;
    sqlx::query(
        r#"
        insert into outbox_events
          (event_id, event_type, aggregate_id, correlation_id, causation_id, payload)
        values ($1, $2, $3, $4, $5, $6)
        on conflict (event_id) do nothing
        "#,
    )
    .bind(envelope.event_id)
    .bind(&envelope.event_type)
    .bind(envelope.aggregate_id)
    .bind(&envelope.correlation_id)
    .bind(envelope.causation_id)
    .bind(payload)
    .execute(&mut **tx)
    .await?;
    Ok(())
}

pub async fn lease_pending_outbox(
    pool: &PgPool,
    lease_seconds: i64,
    limit: i64,
) -> PersistenceResult<Vec<OutboxEventRecord>> {
    let rows = sqlx::query_as::<_, OutboxEventRecord>(
        r#"
        with picked as (
          select event_id
          from outbox_events
          where status in ('pending', 'failed')
            and (leased_until is null or leased_until < now())
          order by created_at
          limit $1
          for update skip locked
        )
        update outbox_events o
        set status = 'leased',
            attempts = attempts + 1,
            leased_until = now() + ($2 || ' seconds')::interval
        from picked
        where o.event_id = picked.event_id
        returning o.event_id, o.event_type, o.aggregate_id, o.correlation_id,
          o.causation_id, o.payload, o.status, o.attempts, o.created_at
        "#,
    )
    .bind(limit)
    .bind(lease_seconds)
    .fetch_all(pool)
    .await?;
    Ok(rows)
}

pub async fn mark_published(pool: &PgPool, event_id: Uuid) -> PersistenceResult<()> {
    sqlx::query(
        r#"
        update outbox_events
        set status = 'published', published_at = now(), leased_until = null
        where event_id = $1
        "#,
    )
    .bind(event_id)
    .execute(pool)
    .await?;
    Ok(())
}

pub async fn mark_failed(pool: &PgPool, event_id: Uuid, error: &str) -> PersistenceResult<()> {
    sqlx::query(
        r#"
        update outbox_events
        set status = 'failed',
            last_error = left($2, 2000),
            leased_until = null
        where event_id = $1
        "#,
    )
    .bind(event_id)
    .bind(error)
    .execute(pool)
    .await?;
    Ok(())
}
