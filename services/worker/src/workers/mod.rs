use institutional_yield_config::AppConfig;
use institutional_yield_domain::{EventEnvelope, SweepCommand};
use institutional_yield_messaging::{MessagingConfig, SnsPublisher, SqsConsumer};
use institutional_yield_persistence::{
    apply_command, default_worker_guard_context, get_failure_injection, get_sweep_order,
    inbox::record_inbox_message,
    outbox::{lease_pending_outbox, mark_failed, mark_published},
    CommandInput,
};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use std::time::Duration;
use uuid::Uuid;

const LOCALSTACK_ACCOUNT_ID: &str = "000000000000";

pub async fn run_outbox_publisher(config: AppConfig, pool: PgPool) -> anyhow::Result<()> {
    let messaging_config = messaging_config(&config);
    let topic_name =
        std::env::var("SNS_TOPIC_NAME").unwrap_or_else(|_| "domain-events".to_string());
    let topic_arn = format!(
        "arn:aws:sns:{}:{}:{}",
        config.aws_region, LOCALSTACK_ACCOUNT_ID, topic_name
    );
    let publisher = SnsPublisher::new(&messaging_config, topic_arn).await?;
    loop {
        tokio::select! {
            _ = tokio::signal::ctrl_c() => return Ok(()),
            _ = publish_once(&pool, &publisher) => {}
        }
        tokio::time::sleep(Duration::from_millis(500)).await;
    }
}

async fn publish_once(pool: &PgPool, publisher: &SnsPublisher) {
    match lease_pending_outbox(pool, 30, 25).await {
        Ok(events) => {
            for event in events {
                match serde_json::from_value::<EventEnvelope>(event.payload.clone()) {
                    Ok(envelope) => match publisher.publish(&envelope).await {
                        Ok(message_id) => {
                            tracing::info!(event_id = %event.event_id, message_id, "published outbox event");
                            if let Err(error) = mark_published(pool, event.event_id).await {
                                tracing::error!(%error, "failed to mark outbox event published");
                            }
                        }
                        Err(error) => {
                            let _ = mark_failed(pool, event.event_id, &error.to_string()).await;
                        }
                    },
                    Err(error) => {
                        let _ = mark_failed(pool, event.event_id, &error.to_string()).await;
                    }
                }
            }
        }
        Err(error) => tracing::error!(%error, "outbox lease failed"),
    }
}

pub async fn run_transfer_agent(config: AppConfig, pool: PgPool) -> anyhow::Result<()> {
    consume_queue(
        &config,
        pool,
        "transfer-agent",
        std::env::var("SQS_TRANSFER_AGENT_QUEUE")
            .unwrap_or_else(|_| "transfer-agent-worker-queue".to_string()),
        handle_transfer_agent_event,
    )
    .await
}

pub async fn run_reconciliation(config: AppConfig, pool: PgPool) -> anyhow::Result<()> {
    consume_queue(
        &config,
        pool,
        "reconciliation",
        std::env::var("SQS_RECONCILIATION_QUEUE")
            .unwrap_or_else(|_| "reconciliation-worker-queue".to_string()),
        handle_reconciliation_event,
    )
    .await
}

pub async fn run_chain_watcher(config: AppConfig, pool: PgPool) -> anyhow::Result<()> {
    consume_queue(
        &config,
        pool,
        "chain-watcher",
        std::env::var("SQS_CHAIN_WATCHER_QUEUE")
            .unwrap_or_else(|_| "chain-watcher-queue".to_string()),
        handle_chain_watcher_event,
    )
    .await
}

pub async fn run_notification(config: AppConfig, pool: PgPool) -> anyhow::Result<()> {
    consume_queue(
        &config,
        pool,
        "notification",
        std::env::var("SQS_NOTIFICATION_QUEUE")
            .unwrap_or_else(|_| "notification-worker-queue".to_string()),
        handle_notification_event,
    )
    .await
}

async fn consume_queue<F, Fut>(
    config: &AppConfig,
    pool: PgPool,
    consumer_name: &'static str,
    queue_name: String,
    handler: F,
) -> anyhow::Result<()>
where
    F: Fn(AppConfig, PgPool, EventEnvelope) -> Fut + Copy,
    Fut: std::future::Future<Output = anyhow::Result<()>>,
{
    let messaging_config = messaging_config(config);
    let queue_url = queue_url(&config.localstack_endpoint, &queue_name);
    let consumer = SqsConsumer::new(&messaging_config, queue_url).await?;
    loop {
        tokio::select! {
            _ = tokio::signal::ctrl_c() => return Ok(()),
            messages = consumer.receive(10, 5) => {
                for message in messages? {
                    let envelope = serde_json::from_str::<EventEnvelope>(&message.body)?;
                    let should_process = record_inbox_message(&pool, consumer_name, &message.message_id, envelope.event_id).await?;
                    if should_process {
                        handler(config.clone(), pool.clone(), envelope).await?;
                    }
                    consumer.delete(&message.receipt_handle).await?;
                }
            }
        }
    }
}

async fn handle_transfer_agent_event(
    config: AppConfig,
    pool: PgPool,
    envelope: EventEnvelope,
) -> anyhow::Result<()> {
    if envelope.event_type != "sweep.order.created.v1" {
        return Ok(());
    }
    let order_id = envelope.aggregate_id;
    apply_if_status(
        &pool,
        order_id,
        "Created",
        SweepCommand::CheckEligibility,
        &envelope.correlation_id,
        None,
        None,
    )
    .await?;
    apply_if_status(
        &pool,
        order_id,
        "EligibilityChecked",
        SweepCommand::CheckDisclosures,
        &envelope.correlation_id,
        None,
        None,
    )
    .await?;
    apply_if_status(
        &pool,
        order_id,
        "DisclosureChecked",
        SweepCommand::Approve,
        &envelope.correlation_id,
        None,
        None,
    )
    .await?;
    apply_if_status(
        &pool,
        order_id,
        "Approved",
        SweepCommand::LockCash,
        &envelope.correlation_id,
        None,
        None,
    )
    .await?;
    apply_if_status(
        &pool,
        order_id,
        "CashLocked",
        SweepCommand::SubmitSubscription,
        &envelope.correlation_id,
        None,
        None,
    )
    .await?;
    let order = get_sweep_order(&pool, order_id).await?;
    if order.status == "SubscriptionSubmitted" {
        let confirmation_ref = request_transfer_agent_confirmation(&config, &order).await?;
        apply_worker_command(
            &pool,
            order_id,
            SweepCommand::ConfirmTransferAgent,
            &envelope.correlation_id,
            Some(confirmation_ref.clone()),
            None,
        )
        .await?;
        apply_worker_command(
            &pool,
            order_id,
            SweepCommand::BookPosition,
            &envelope.correlation_id,
            Some(confirmation_ref),
            None,
        )
        .await?;
    }
    Ok(())
}

async fn handle_reconciliation_event(
    _config: AppConfig,
    pool: PgPool,
    envelope: EventEnvelope,
) -> anyhow::Result<()> {
    if envelope.event_type != "sweep.position.booked.v1" {
        return Ok(());
    }
    let order = get_sweep_order(&pool, envelope.aggregate_id).await?;
    if matches!(
        order.status.as_str(),
        "Active" | "ExceptionOpen" | "ExceptionClosed"
    ) {
        return Ok(());
    }
    if order.status == "Reconciled" {
        apply_worker_command(
            &pool,
            envelope.aggregate_id,
            SweepCommand::Activate,
            &envelope.correlation_id,
            None,
            None,
        )
        .await?;
        return Ok(());
    }
    let mismatch = get_failure_injection(&pool, "reconciliation-mismatch").await?;
    if mismatch {
        apply_worker_command(
            &pool,
            envelope.aggregate_id,
            SweepCommand::OpenException,
            &envelope.correlation_id,
            None,
            Some("local reconciliation mismatch injected".to_string()),
        )
        .await?;
    } else {
        apply_worker_command(
            &pool,
            envelope.aggregate_id,
            SweepCommand::Reconcile,
            &envelope.correlation_id,
            None,
            None,
        )
        .await?;
        apply_worker_command(
            &pool,
            envelope.aggregate_id,
            SweepCommand::Activate,
            &envelope.correlation_id,
            None,
            None,
        )
        .await?;
    }
    Ok(())
}

async fn handle_chain_watcher_event(
    _config: AppConfig,
    _pool: PgPool,
    envelope: EventEnvelope,
) -> anyhow::Result<()> {
    if envelope.event_type == "sweep.transfer_agent.confirmed.v1" {
        tracing::info!(event_id = %envelope.event_id, "chain mirror not required for local FYOXX flow");
    }
    Ok(())
}

async fn handle_notification_event(
    _config: AppConfig,
    _pool: PgPool,
    envelope: EventEnvelope,
) -> anyhow::Result<()> {
    tracing::info!(event_id = %envelope.event_id, event_type = %envelope.event_type, "notification projection consumed event");
    Ok(())
}

async fn apply_if_status(
    pool: &PgPool,
    order_id: Uuid,
    expected_status: &str,
    command: SweepCommand,
    correlation_id: &str,
    confirmation_ref: Option<String>,
    break_reason: Option<String>,
) -> anyhow::Result<()> {
    let order = get_sweep_order(pool, order_id).await?;
    if order.status == expected_status {
        apply_worker_command(
            pool,
            order_id,
            command,
            correlation_id,
            confirmation_ref,
            break_reason,
        )
        .await?;
    }
    Ok(())
}

async fn apply_worker_command(
    pool: &PgPool,
    order_id: Uuid,
    command: SweepCommand,
    correlation_id: &str,
    confirmation_ref: Option<String>,
    break_reason: Option<String>,
) -> anyhow::Result<()> {
    apply_command(
        pool,
        CommandInput {
            order_id,
            command,
            correlation_id: correlation_id.to_string(),
            idempotency_key: None,
            confirmation_ref,
            external_order_ref: None,
            break_reason,
            guard_context: default_worker_guard_context(),
        },
    )
    .await?;
    Ok(())
}

#[derive(Debug, Serialize)]
struct TransferAgentRequest {
    order_id: Uuid,
    idempotency_key: String,
    amount: String,
    product_asset: String,
}

#[derive(Debug, Deserialize)]
struct TransferAgentResponse {
    confirmation_ref: String,
}

async fn request_transfer_agent_confirmation(
    config: &AppConfig,
    order: &institutional_yield_persistence::SweepOrderRecord,
) -> anyhow::Result<String> {
    let response = reqwest::Client::new()
        .post(format!("{}/subscriptions", config.mock_transfer_agent_url))
        .json(&TransferAgentRequest {
            order_id: order.order_id,
            idempotency_key: format!("subscription-{}", order.order_id),
            amount: order.amount.to_string(),
            product_asset: order.product_asset.clone(),
        })
        .send()
        .await?
        .error_for_status()?
        .json::<TransferAgentResponse>()
        .await?;
    Ok(response.confirmation_ref)
}

fn messaging_config(config: &AppConfig) -> MessagingConfig {
    MessagingConfig {
        app_env: config.app_env.clone(),
        endpoint_url: config.localstack_endpoint.clone(),
        region: config.aws_region.clone(),
    }
}

fn queue_url(endpoint: &str, queue_name: &str) -> String {
    format!(
        "{}/{}/{}",
        endpoint.trim_end_matches('/'),
        LOCALSTACK_ACCOUNT_ID,
        queue_name
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn local_queue_url_uses_configured_endpoint() {
        assert_eq!(
            queue_url("http://localstack:4566", "transfer-agent-worker-queue"),
            "http://localstack:4566/000000000000/transfer-agent-worker-queue"
        );
    }
}
