# Postgres Ledger Integrity

## Connect

```bash
docker compose exec postgres psql -U yield -d yield_control
```

## Check Ledger Balance

```sql
select order_id, asset, sum(amount) as net_amount
from ledger_entries
group by order_id, asset
having sum(amount) <> 0;
```

The query should return no rows. Domain tests and persistence tests enforce balanced ledger entry groups.

## Check Append-Only Enforcement

```bash
RUN_DATABASE_TESTS=1 DATABASE_URL=postgres://yield:yield@127.0.0.1:15432/yield_control cargo test -p institutional-yield-persistence --all-features ledger_entries_are_append_only
```

