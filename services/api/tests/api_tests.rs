use axum::{body::Body, http::Request};
use institutional_yield_api::build_router;
use sqlx::postgres::PgPoolOptions;
use tower::ServiceExt;

fn test_app() -> axum::Router {
    let pool = PgPoolOptions::new()
        .connect_lazy("postgres://yield:yield@localhost:15432/yield_control")
        .expect("lazy pool");
    build_router(pool)
}

#[tokio::test]
async fn write_routes_require_idempotency_key() {
    let response = test_app()
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/sweep-orders")
                .header("Content-Type", "application/json")
                .header("Correlation-Id", "api-test")
                .body(Body::from(
                    r#"{"account_id":"11111111-1111-4111-8111-111111111111","amount":"10.00","cash_asset":"USD","product_asset":"FYOXX"}"#,
                ))
                .expect("request"),
        )
        .await
        .expect("response");
    assert_eq!(response.status(), axum::http::StatusCode::BAD_REQUEST);
}

#[tokio::test]
async fn attempt_fidd_yield_is_rejected_by_domain_rule() {
    let response = test_app()
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/dev/attempt-fidd-yield")
                .header("Content-Type", "application/json")
                .header("Correlation-Id", "api-test")
                .header("Idempotency-Key", "api-test")
                .body(Body::from(
                    r#"{"account_id":"11111111-1111-4111-8111-111111111111","amount":"1.00"}"#,
                ))
                .expect("request"),
        )
        .await
        .expect("response");
    assert_eq!(
        response.status(),
        axum::http::StatusCode::UNPROCESSABLE_ENTITY
    );
}
