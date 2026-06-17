use anyhow::{anyhow, Context};
use chrono::{DateTime, Utc};
use institutional_yield_persistence::{connect, migrate};
use serde::Serialize;
use sqlx::PgPool;
use std::{env, fs, process::Command};

#[derive(Debug, Serialize)]
struct CertificationReport {
    generated_at: DateTime<Utc>,
    git_sha: String,
    app_env: String,
    aws_region: String,
    checks_passed: usize,
    checks_failed: usize,
    checks_warned: usize,
    checks: Vec<CertificationCheck>,
}

#[derive(Debug, Serialize)]
struct CertificationCheck {
    id: &'static str,
    status: CheckStatus,
    observed: i64,
    evidence: String,
}

#[derive(Debug, Clone, Copy, Serialize)]
#[serde(rename_all = "lowercase")]
enum CheckStatus {
    Pass,
    Fail,
    Warn,
}

impl CertificationCheck {
    fn pass_fail(id: &'static str, observed: i64, evidence: impl Into<String>) -> Self {
        Self {
            id,
            status: if observed == 0 {
                CheckStatus::Pass
            } else {
                CheckStatus::Fail
            },
            observed,
            evidence: evidence.into(),
        }
    }

    fn warn(id: &'static str, evidence: impl Into<String>) -> Self {
        Self {
            id,
            status: CheckStatus::Warn,
            observed: 0,
            evidence: evidence.into(),
        }
    }
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let database_url = env::var("DATABASE_URL").context("DATABASE_URL is required")?;
    let pool = connect(&database_url).await?;
    migrate(&pool).await?;

    let mut checks = vec![
        count_check(
            &pool,
            "no_duplicate_idempotency_records",
            r#"
            select count(*) from (
              select scope, key_hash
              from idempotency_records
              group by scope, key_hash
              having count(*) > 1
            ) violations
            "#,
        )
        .await?,
        count_check(
            &pool,
            "no_conflicting_idempotency_bodies",
            r#"
            select count(*) from (
              select scope, key_hash
              from idempotency_records
              group by scope, key_hash
              having count(distinct request_hash) > 1
            ) violations
            "#,
        )
        .await?,
        count_check(
            &pool,
            "no_duplicate_transfer_agent_confirmations",
            r#"
            select count(*) from (
              select transfer_agent_confirmation_ref
              from positions
              group by transfer_agent_confirmation_ref
              having count(*) > 1
            ) violations
            "#,
        )
        .await?,
        count_check(
            &pool,
            "one_position_per_order",
            r#"
            select count(*) from (
              select order_id
              from positions
              group by order_id
              having count(*) > 1
            ) violations
            "#,
        )
        .await?,
        count_check(
            &pool,
            "active_requires_reconciled_history",
            r#"
            select count(*)
            from sweep_orders orders
            where orders.status = 'Active'
              and not exists (
                select 1
                from state_transitions transitions
                where transitions.order_id = orders.order_id
                  and transitions.to_status = 'Reconciled'
              )
            "#,
        )
        .await?,
        count_check(
            &pool,
            "ledger_balanced_per_asset_order_kind",
            r#"
            select count(*) from (
              select order_id, asset, entry_kind,
                sum(case when debit_credit = 'Debit' then amount else -amount end) as signed_amount
              from ledger_entries
              where order_id is not null
              group by order_id, asset, entry_kind
              having sum(case when debit_credit = 'Debit' then amount else -amount end) <> 0
            ) violations
            "#,
        )
        .await?,
        count_check(
            &pool,
            "inbox_deduplicates_worker_effects",
            r#"
            select count(*) from (
              select consumer, message_id
              from inbox_messages
              group by consumer, message_id
              having count(*) > 1
            ) violations
            "#,
        )
        .await?,
        count_check(
            &pool,
            "outbox_retry_does_not_duplicate_business_events",
            r#"
            select count(*) from (
              select aggregate_id, event_type
              from audit_events
              where event_type in (
                'sweep.position.booked.v1',
                'sweep.active.v1',
                'redemption.cash_credited.v1',
                'reconciliation.break.opened.v1'
              )
              group by aggregate_id, event_type
              having count(*) > 1
            ) violations
            "#,
        )
        .await?,
        count_check(
            &pool,
            "outbox_has_no_stale_unpublished_events",
            r#"
            select count(*)
            from outbox_events
            where status in ('pending', 'leased', 'failed')
              and created_at < now() - interval '5 minutes'
            "#,
        )
        .await?,
    ];
    checks.push(append_only_check(&pool).await?);

    let checks_passed = checks
        .iter()
        .filter(|check| matches!(check.status, CheckStatus::Pass))
        .count();
    let checks_failed = checks
        .iter()
        .filter(|check| matches!(check.status, CheckStatus::Fail))
        .count();
    let checks_warned = checks
        .iter()
        .filter(|check| matches!(check.status, CheckStatus::Warn))
        .count();
    let report = CertificationReport {
        generated_at: Utc::now(),
        git_sha: git_sha(),
        app_env: env::var("APP_ENV").unwrap_or_else(|_| "unknown".to_string()),
        aws_region: env::var("AWS_REGION").unwrap_or_else(|_| "unknown".to_string()),
        checks_passed,
        checks_failed,
        checks_warned,
        checks,
    };
    let compact_output = env::var("AWS_CERT_PROBE_COMPACT").as_deref() == Ok("1");
    let report_json = if compact_output {
        serde_json::to_string(&report)?
    } else {
        serde_json::to_string_pretty(&report)?
    };
    if let Ok(output_path) = env::var("AWS_CERT_PROBE_OUTPUT") {
        fs::write(&output_path, format!("{report_json}\n"))
            .with_context(|| format!("write {output_path}"))?;
    } else {
        println!("{report_json}");
    }
    if checks_failed > 0 {
        return Err(anyhow!("{checks_failed} certification checks failed"));
    }
    Ok(())
}

async fn count_check(
    pool: &PgPool,
    id: &'static str,
    query: &'static str,
) -> anyhow::Result<CertificationCheck> {
    let observed = sqlx::query_scalar::<_, i64>(query)
        .fetch_one(pool)
        .await
        .with_context(|| format!("run certification check {id}"))?;
    Ok(CertificationCheck::pass_fail(id, observed, query.trim()))
}

async fn append_only_check(pool: &PgPool) -> anyhow::Result<CertificationCheck> {
    let ledger_entries = sqlx::query_scalar::<_, i64>("select count(*) from ledger_entries")
        .fetch_one(pool)
        .await?;
    if ledger_entries == 0 {
        return Ok(CertificationCheck::warn(
            "ledger_append_only_trigger_enforced",
            "No ledger entries exist yet, so the mutation trigger was not exercised.",
        ));
    }
    let result = sqlx::query(
        r#"
        update ledger_entries
        set amount = amount
        where entry_id = (select entry_id from ledger_entries limit 1)
        "#,
    )
    .execute(pool)
    .await;
    match result {
        Ok(_) => Ok(CertificationCheck {
            id: "ledger_append_only_trigger_enforced",
            status: CheckStatus::Fail,
            observed: 1,
            evidence: "A ledger update succeeded; append-only trigger did not block mutation."
                .to_string(),
        }),
        Err(error) => Ok(CertificationCheck {
            id: "ledger_append_only_trigger_enforced",
            status: CheckStatus::Pass,
            observed: 0,
            evidence: error.to_string(),
        }),
    }
}

fn git_sha() -> String {
    if let Ok(value) = std::env::var("GIT_SHA") {
        if !value.trim().is_empty() {
            return value;
        }
    }

    Command::new("git")
        .args(["rev-parse", "HEAD"])
        .output()
        .ok()
        .filter(|output| output.status.success())
        .map(|output| String::from_utf8_lossy(&output.stdout).trim().to_string())
        .filter(|value| !value.is_empty())
        .unwrap_or_else(|| "unknown".to_string())
}
