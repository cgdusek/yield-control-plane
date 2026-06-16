pub mod error;
pub mod middleware;
pub mod openapi;
pub mod routes;

use axum::Router;
use sqlx::PgPool;
use tower_http::{cors::CorsLayer, trace::TraceLayer};

#[derive(Clone)]
pub struct AppState {
    pub pool: PgPool,
}

pub fn build_router(pool: PgPool) -> Router {
    Router::new()
        .merge(routes::router())
        .layer(CorsLayer::permissive())
        .layer(TraceLayer::new_for_http())
        .with_state(AppState { pool })
}
