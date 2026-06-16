use crate::PersistenceResult;
use sqlx::{postgres::PgPoolOptions, PgPool};
use std::time::Duration;

pub async fn connect(database_url: &str) -> PersistenceResult<PgPool> {
    Ok(PgPoolOptions::new()
        .max_connections(10)
        .acquire_timeout(Duration::from_secs(10))
        .connect(database_url)
        .await?)
}

pub async fn migrate(pool: &PgPool) -> PersistenceResult<()> {
    sqlx::migrate!("./migrations").run(pool).await?;
    Ok(())
}
