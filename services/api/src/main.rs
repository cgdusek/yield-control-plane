use institutional_yield_api::build_router;
use institutional_yield_config::AppConfig;
use institutional_yield_observability::init_tracing;
use institutional_yield_persistence::{connect, migrate};
use tokio::net::TcpListener;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    init_tracing("api");
    let config = AppConfig::from_env()?;
    let pool = connect(&config.database_url).await?;
    migrate(&pool).await?;
    let listener = TcpListener::bind(&config.api_bind_addr).await?;
    tracing::info!(addr = %config.api_bind_addr, "api listening");
    axum::serve(listener, build_router(pool))
        .with_graceful_shutdown(shutdown_signal())
        .await?;
    Ok(())
}

async fn shutdown_signal() {
    let ctrl_c = async {
        let _ = tokio::signal::ctrl_c().await;
    };
    #[cfg(unix)]
    let terminate = async {
        if let Ok(mut signal) =
            tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())
        {
            signal.recv().await;
        }
    };
    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();
    tokio::select! {
        _ = ctrl_c => {},
        _ = terminate => {},
    }
}
