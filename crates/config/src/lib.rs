use serde::{Deserialize, Serialize};
use thiserror::Error;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AppConfig {
    pub app_env: String,
    pub database_url: String,
    pub api_bind_addr: String,
    pub localstack_endpoint: String,
    pub aws_region: String,
    pub mock_transfer_agent_url: String,
}

#[derive(Debug, Error, PartialEq, Eq)]
pub enum ConfigError {
    #[error("local mode requires a local LocalStack endpoint, got {0}")]
    NonLocalAwsEndpoint(String),
}

impl AppConfig {
    pub fn from_env() -> Result<Self, ConfigError> {
        let app_env = std::env::var("APP_ENV").unwrap_or_else(|_| "local".to_string());
        let database_url = std::env::var("DATABASE_URL")
            .or_else(|_| std::env::var("DATABASE_URL_DOCKER"))
            .unwrap_or_else(|_| "postgres://yield:yield@localhost:15432/yield_control".to_string());
        let api_bind_addr =
            std::env::var("API_BIND_ADDR").unwrap_or_else(|_| "0.0.0.0:8080".to_string());
        let localstack_endpoint = std::env::var("LOCALSTACK_ENDPOINT")
            .or_else(|_| std::env::var("LOCALSTACK_ENDPOINT_DOCKER"))
            .unwrap_or_else(|_| "http://localhost:4566".to_string());
        let aws_region = std::env::var("AWS_REGION").unwrap_or_else(|_| "us-east-1".to_string());
        let mock_transfer_agent_url = std::env::var("MOCK_TRANSFER_AGENT_URL")
            .or_else(|_| std::env::var("MOCK_TRANSFER_AGENT_URL_DOCKER"))
            .unwrap_or_else(|_| "http://localhost:8090".to_string());

        let config = Self {
            app_env,
            database_url,
            api_bind_addr,
            localstack_endpoint,
            aws_region,
            mock_transfer_agent_url,
        };
        config.validate_local_endpoints()?;
        Ok(config)
    }

    pub fn validate_local_endpoints(&self) -> Result<(), ConfigError> {
        if self.app_env == "local" || self.app_env == "dev" {
            let endpoint = self.localstack_endpoint.to_ascii_lowercase();
            let allowed = endpoint.contains("localhost")
                || endpoint.contains("127.0.0.1")
                || endpoint.contains("localstack")
                || endpoint.contains("::1");
            if !allowed {
                return Err(ConfigError::NonLocalAwsEndpoint(
                    self.localstack_endpoint.clone(),
                ));
            }
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_real_aws_endpoint_in_local_mode() {
        let config = AppConfig {
            app_env: "local".to_string(),
            database_url: "postgres://yield:yield@localhost:15432/yield_control".to_string(),
            api_bind_addr: "127.0.0.1:8080".to_string(),
            localstack_endpoint: "https://sns.us-east-1.amazonaws.com".to_string(),
            aws_region: "us-east-1".to_string(),
            mock_transfer_agent_url: "http://localhost:8090".to_string(),
        };
        assert_eq!(
            config.validate_local_endpoints(),
            Err(ConfigError::NonLocalAwsEndpoint(
                "https://sns.us-east-1.amazonaws.com".to_string()
            ))
        );
    }
}
