use aws_config::BehaviorVersion;
use aws_credential_types::{provider::SharedCredentialsProvider, Credentials};
use aws_types::{region::Region, SdkConfig};
use thiserror::Error;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MessagingConfig {
    pub app_env: String,
    pub endpoint_url: String,
    pub region: String,
}

impl MessagingConfig {
    pub fn from_env() -> Self {
        Self {
            app_env: std::env::var("APP_ENV").unwrap_or_else(|_| "local".to_string()),
            endpoint_url: std::env::var("LOCALSTACK_ENDPOINT")
                .unwrap_or_else(|_| "http://localhost:4566".to_string()),
            region: std::env::var("AWS_REGION").unwrap_or_else(|_| "us-east-1".to_string()),
        }
    }
}

#[derive(Debug, Error)]
pub enum MessagingError {
    #[error("local mode requires a LocalStack or localhost endpoint, got {endpoint}")]
    RealAwsEndpointBlocked { endpoint: String },
    #[error(transparent)]
    Serde(#[from] serde_json::Error),
    #[error("AWS SDK error: {0}")]
    Sdk(String),
}

pub type MessagingResult<T> = Result<T, MessagingError>;

pub fn validate_local_endpoint(config: &MessagingConfig) -> MessagingResult<()> {
    if config.app_env == "local" || config.app_env == "dev" {
        let endpoint = config.endpoint_url.to_ascii_lowercase();
        let allowed = endpoint.contains("localhost")
            || endpoint.contains("127.0.0.1")
            || endpoint.contains("localstack")
            || endpoint.contains("::1");
        if !allowed {
            return Err(MessagingError::RealAwsEndpointBlocked {
                endpoint: config.endpoint_url.clone(),
            });
        }
    }
    Ok(())
}

pub async fn build_aws_config(config: &MessagingConfig) -> MessagingResult<SdkConfig> {
    validate_local_endpoint(config)?;
    let credentials = Credentials::new("test", "test", None, None, "localstack");
    Ok(aws_config::defaults(BehaviorVersion::latest())
        .region(Region::new(config.region.clone()))
        .endpoint_url(config.endpoint_url.clone())
        .credentials_provider(SharedCredentialsProvider::new(credentials))
        .load()
        .await)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn local_mode_allows_localstack_endpoint() {
        let config = MessagingConfig {
            app_env: "local".to_string(),
            endpoint_url: "http://localhost:4566".to_string(),
            region: "us-east-1".to_string(),
        };
        validate_local_endpoint(&config).expect("local endpoint accepted");
    }

    #[test]
    fn local_mode_rejects_real_aws_endpoint() {
        let config = MessagingConfig {
            app_env: "local".to_string(),
            endpoint_url: "https://sqs.us-east-1.amazonaws.com".to_string(),
            region: "us-east-1".to_string(),
        };
        assert!(matches!(
            validate_local_endpoint(&config),
            Err(MessagingError::RealAwsEndpointBlocked { .. })
        ));
    }
}
