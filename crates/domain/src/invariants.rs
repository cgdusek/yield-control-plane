use crate::{Asset, DomainError, DomainResult};

pub fn ensure_yield_source_allowed(asset: &Asset) -> DomainResult<()> {
    if asset.is_yield_bearing_allowed() {
        Ok(())
    } else {
        Err(DomainError::YieldOnCashRailForbidden {
            asset: asset.to_string(),
        })
    }
}
