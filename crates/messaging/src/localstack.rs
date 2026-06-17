use aws_config::BehaviorVersion;
use aws_credential_types::{provider::SharedCredentialsProvider, Credentials};
use aws_types::{region::Region, SdkConfig};
use thiserror::Error;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MessagingConfig {
    pub app_env: String,
    pub endpoint_url: Option<String>,
    pub region: String,
    pub aws_certification_enabled: bool,
}

impl MessagingConfig {
    pub fn from_env() -> Self {
        let app_env = std::env::var("APP_ENV").unwrap_or_else(|_| "local".to_string());
        let endpoint_url = if app_env == "cert" {
            None
        } else {
            Some(
                std::env::var("LOCALSTACK_ENDPOINT")
                    .unwrap_or_else(|_| "http://localhost:4566".to_string()),
            )
        };
        Self {
            app_env,
            endpoint_url,
            region: std::env::var("AWS_REGION").unwrap_or_else(|_| "us-east-1".to_string()),
            aws_certification_enabled: std::env::var("AWS_CERTIFICATION_ENABLED").ok().as_deref()
                == Some("1"),
        }
    }
}

#[derive(Debug, Error)]
pub enum MessagingError {
    #[error("local mode requires a LocalStack or localhost endpoint, got {endpoint}")]
    RealAwsEndpointBlocked { endpoint: String },
    #[error("local mode requires LOCALSTACK_ENDPOINT")]
    LocalEndpointRequired,
    #[error("APP_ENV=cert requires AWS_CERTIFICATION_ENABLED=1")]
    CertModeRequiresExplicitOptIn,
    #[error("APP_ENV=cert must use AWS SDK default endpoints, got endpoint override {endpoint}")]
    CertModeRejectsEndpointOverride { endpoint: String },
    #[error(transparent)]
    Serde(#[from] serde_json::Error),
    #[error("AWS SDK error: {0}")]
    Sdk(String),
}

pub type MessagingResult<T> = Result<T, MessagingError>;

pub fn validate_local_endpoint(config: &MessagingConfig) -> MessagingResult<()> {
    if config.app_env == "local" || config.app_env == "dev" {
        let endpoint_url = config
            .endpoint_url
            .as_ref()
            .ok_or(MessagingError::LocalEndpointRequired)?;
        let endpoint = endpoint_url.to_ascii_lowercase();
        let allowed = endpoint.contains("localhost")
            || endpoint.contains("127.0.0.1")
            || endpoint.contains("localstack")
            || endpoint.contains("::1");
        if !allowed {
            return Err(MessagingError::RealAwsEndpointBlocked {
                endpoint: endpoint_url.clone(),
            });
        }
    }
    if config.app_env == "cert" {
        if !config.aws_certification_enabled {
            return Err(MessagingError::CertModeRequiresExplicitOptIn);
        }
        if let Some(endpoint) = &config.endpoint_url {
            return Err(MessagingError::CertModeRejectsEndpointOverride {
                endpoint: endpoint.clone(),
            });
        }
    }
    Ok(())
}

pub async fn build_aws_config(config: &MessagingConfig) -> MessagingResult<SdkConfig> {
    validate_local_endpoint(config)?;
    let loader =
        aws_config::defaults(BehaviorVersion::latest()).region(Region::new(config.region.clone()));
    let loader = if config.app_env == "local" || config.app_env == "dev" {
        let credentials = Credentials::new("test", "test", None, None, "localstack");
        loader
            .endpoint_url(
                config
                    .endpoint_url
                    .as_ref()
                    .ok_or(MessagingError::LocalEndpointRequired)?
                    .clone(),
            )
            .credentials_provider(SharedCredentialsProvider::new(credentials))
    } else {
        loader
    };
    Ok(loader.load().await)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn local_mode_allows_localstack_endpoint() {
        let config = MessagingConfig {
            app_env: "local".to_string(),
            endpoint_url: Some("http://localhost:4566".to_string()),
            region: "us-east-1".to_string(),
            aws_certification_enabled: false,
        };
        validate_local_endpoint(&config).expect("local endpoint accepted");
    }

    #[test]
    fn local_mode_rejects_real_aws_endpoint() {
        let config = MessagingConfig {
            app_env: "local".to_string(),
            endpoint_url: Some("https://sqs.us-east-1.amazonaws.com".to_string()),
            region: "us-east-1".to_string(),
            aws_certification_enabled: false,
        };
        assert!(matches!(
            validate_local_endpoint(&config),
            Err(MessagingError::RealAwsEndpointBlocked { .. })
        ));
    }

    #[test]
    fn cert_mode_uses_default_aws_endpoints_with_explicit_opt_in() {
        let config = MessagingConfig {
            app_env: "cert".to_string(),
            endpoint_url: None,
            region: "us-west-2".to_string(),
            aws_certification_enabled: true,
        };
        validate_local_endpoint(&config).expect("cert config accepted");
    }

    #[test]
    fn cert_mode_rejects_endpoint_override() {
        let config = MessagingConfig {
            app_env: "cert".to_string(),
            endpoint_url: Some("http://localhost:4566".to_string()),
            region: "us-west-2".to_string(),
            aws_certification_enabled: true,
        };
        assert!(matches!(
            validate_local_endpoint(&config),
            Err(MessagingError::CertModeRejectsEndpointOverride { .. })
        ));
    }
}
