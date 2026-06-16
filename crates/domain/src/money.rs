use crate::{Asset, DomainError, DomainResult};
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Money {
    #[serde(with = "rust_decimal::serde::str")]
    pub amount: Decimal,
    pub asset: Asset,
}

impl Money {
    pub fn new(amount: Decimal, asset: Asset) -> DomainResult<Self> {
        if amount.is_sign_negative() {
            return Err(DomainError::NegativeAmount);
        }
        Ok(Self { amount, asset })
    }

    pub fn zero(asset: Asset) -> Self {
        Self {
            amount: Decimal::ZERO,
            asset,
        }
    }

    pub fn checked_add(&self, other: &Self) -> DomainResult<Self> {
        if self.asset != other.asset {
            return Err(DomainError::AssetMismatch);
        }
        Money::new(self.amount + other.amount, self.asset.clone())
    }

    pub fn checked_sub(&self, other: &Self) -> DomainResult<Self> {
        if self.asset != other.asset {
            return Err(DomainError::AssetMismatch);
        }
        Money::new(self.amount - other.amount, self.asset.clone())
    }
}
