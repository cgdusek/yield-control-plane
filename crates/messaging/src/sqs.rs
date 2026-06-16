use crate::localstack::{build_aws_config, MessagingConfig, MessagingError, MessagingResult};
use aws_sdk_sqs::Client;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SqsMessage {
    pub message_id: String,
    pub receipt_handle: String,
    pub body: String,
}

#[derive(Clone)]
pub struct SqsConsumer {
    client: Client,
    queue_url: String,
}

impl SqsConsumer {
    pub async fn new(
        config: &MessagingConfig,
        queue_url: impl Into<String>,
    ) -> MessagingResult<Self> {
        let sdk_config = build_aws_config(config).await?;
        Ok(Self {
            client: Client::new(&sdk_config),
            queue_url: queue_url.into(),
        })
    }

    pub fn from_client(client: Client, queue_url: impl Into<String>) -> Self {
        Self {
            client,
            queue_url: queue_url.into(),
        }
    }

    pub async fn receive(
        &self,
        wait_seconds: i32,
        max_messages: i32,
    ) -> MessagingResult<Vec<SqsMessage>> {
        let output = self
            .client
            .receive_message()
            .queue_url(&self.queue_url)
            .wait_time_seconds(wait_seconds)
            .max_number_of_messages(max_messages)
            .send()
            .await
            .map_err(|error| MessagingError::Sdk(error.to_string()))?;

        Ok(output
            .messages()
            .iter()
            .filter_map(|message| {
                Some(SqsMessage {
                    message_id: message.message_id()?.to_string(),
                    receipt_handle: message.receipt_handle()?.to_string(),
                    body: message.body()?.to_string(),
                })
            })
            .collect())
    }

    pub async fn delete(&self, receipt_handle: &str) -> MessagingResult<()> {
        self.client
            .delete_message()
            .queue_url(&self.queue_url)
            .receipt_handle(receipt_handle)
            .send()
            .await
            .map_err(|error| MessagingError::Sdk(error.to_string()))?;
        Ok(())
    }
}
