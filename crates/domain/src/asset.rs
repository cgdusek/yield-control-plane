use serde::{Deserialize, Serialize};
use std::{fmt, str::FromStr};

#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "UPPERCASE")]
pub enum Asset {
    USD,
    FIDD,
    ETH,
    BTC,
    ProductAsset(String),
}

impl Asset {
    pub fn symbol(&self) -> &str {
        match self {
            Asset::USD => "USD",
            Asset::FIDD => "FIDD",
            Asset::ETH => "ETH",
            Asset::BTC => "BTC",
            Asset::ProductAsset(symbol) => symbol.as_str(),
        }
    }

    pub fn is_cash_rail(&self) -> bool {
        matches!(self, Asset::USD | Asset::FIDD)
    }

    pub fn is_yield_bearing_allowed(&self) -> bool {
        !matches!(self, Asset::FIDD)
    }
}

impl fmt::Display for Asset {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(self.symbol())
    }
}

impl FromStr for Asset {
    type Err = crate::DomainError;

    fn from_str(value: &str) -> Result<Self, Self::Err> {
        let trimmed = value.trim();
        if trimmed.is_empty() {
            return Err(crate::DomainError::Parse(
                "asset symbol is empty".to_string(),
            ));
        }
        Ok(match trimmed.to_ascii_uppercase().as_str() {
            "USD" => Asset::USD,
            "FIDD" => Asset::FIDD,
            "ETH" => Asset::ETH,
            "BTC" => Asset::BTC,
            _ => Asset::ProductAsset(trimmed.to_string()),
        })
    }
}
