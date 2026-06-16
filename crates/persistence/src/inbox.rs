use crate::PersistenceResult;
use sqlx::PgPool;
use uuid::Uuid;

pub async fn record_inbox_message(
    pool: &PgPool,
    consumer: &str,
    message_id: &str,
    event_id: Uuid,
) -> PersistenceResult<bool> {
    let result = sqlx::query(
        r#"
        insert into inbox_messages (consumer, message_id, event_id)
        values ($1, $2, $3)
        on conflict (consumer, message_id) do nothing
        "#,
    )
    .bind(consumer)
    .bind(message_id)
    .bind(event_id)
    .execute(pool)
    .await?;
    Ok(result.rows_affected() == 1)
}
