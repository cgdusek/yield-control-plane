use tracing_subscriber::{fmt, EnvFilter};

pub fn init_tracing(service_name: &str) {
    let env_filter = EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info"));
    let _ = fmt()
        .json()
        .with_env_filter(env_filter)
        .with_target(true)
        .with_current_span(true)
        .with_span_list(true)
        .try_init();
    tracing::info!(service = service_name, "tracing initialized");
}

pub fn metrics_snapshot(service_name: &str) -> String {
    format!(
        "# HELP ycp_service_info Static service info\n# TYPE ycp_service_info gauge\nycp_service_info{{service=\"{}\"}} 1\n",
        service_name
    )
}
