mod workers;

use institutional_yield_config::AppConfig;
use institutional_yield_observability::init_tracing;
use institutional_yield_persistence::{connect, migrate};
use workers::{
    run_chain_watcher, run_notification, run_outbox_publisher, run_reconciliation,
    run_transfer_agent,
};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let worker_kind =
        std::env::var("WORKER_KIND").unwrap_or_else(|_| "outbox-publisher".to_string());
    init_tracing(&format!("worker-{worker_kind}"));
    let config = AppConfig::from_env()?;
    let pool = connect(&config.database_url).await?;
    migrate(&pool).await?;
    match worker_kind.as_str() {
        "outbox-publisher" => run_outbox_publisher(config, pool).await?,
        "transfer-agent" => run_transfer_agent(config, pool).await?,
        "reconciliation" => run_reconciliation(config, pool).await?,
        "chain-watcher" => run_chain_watcher(config, pool).await?,
        "notification" => run_notification(config, pool).await?,
        other => anyhow::bail!("unknown WORKER_KIND {other}"),
    }
    Ok(())
}
