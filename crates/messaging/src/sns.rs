use crate::localstack::{build_aws_config, MessagingConfig, MessagingError, MessagingResult};
use aws_sdk_sns::Client;
use institutional_yield_domain::EventEnvelope;

#[derive(Clone)]
pub struct SnsPublisher {
    client: Client,
    topic_arn: String,
}

impl SnsPublisher {
    pub async fn new(
        config: &MessagingConfig,
        topic_arn: impl Into<String>,
    ) -> MessagingResult<Self> {
        let sdk_config = build_aws_config(config).await?;
        Ok(Self {
            client: Client::new(&sdk_config),
            topic_arn: topic_arn.into(),
        })
    }

    pub fn from_client(client: Client, topic_arn: impl Into<String>) -> Self {
        Self {
            client,
            topic_arn: topic_arn.into(),
        }
    }

    pub async fn publish(&self, envelope: &EventEnvelope) -> MessagingResult<String> {
        let message = serde_json::to_string(envelope)?;
        let output = self
            .client
            .publish()
            .topic_arn(&self.topic_arn)
            .message(message)
            .send()
            .await
            .map_err(|error| MessagingError::Sdk(error.to_string()))?;
        Ok(output.message_id().unwrap_or_default().to_string())
    }
}
