# PostgreSQL Lock-Chain Lab

A simple `SELECT` can wait behind a schema migration that is still waiting for its own lock. This lab recreates that chain and shows how to trace it back to the open transaction.

**Open transaction → Waiting migration → Waiting SELECT**

This lab uses PostgreSQL 17, Docker Compose, and one synthetic row. It runs locally in a disposable database.

[Read Issue #001 of The Breakdown Files](https://nodarcstudio.substack.com/p/why-a-simple-postgresql-select-timed) for the full investigation, including the separate PostgreSQL and Node.js timeout experiments.

## 1. Start the database

Install Docker with Docker Compose, download this repository, and open a terminal in the folder containing `compose.yaml`. Run:

```sh
docker compose up -d --wait
```

Open four terminal windows in the same folder. In each window, connect to PostgreSQL with:

```sh
docker compose exec db psql -U lab -d locklab
```

## 2. Session A · Leave a transaction open

```sql
SET application_name = 'lock-lab-a';

BEGIN;
SELECT * FROM orders;
```

The query returns one row. Leave the transaction open and keep this window running.

## 3. Session B · Queue the migration

```sql
SET application_name = 'lock-lab-b';

ALTER TABLE orders ADD COLUMN note text;
```

Wait until you see that the command stays pending. It needs a table lock that conflicts with the lock held by Session A.

## 4. Session C · Run the later SELECT

```sql
SET application_name = 'lock-lab-c';

SELECT * FROM orders WHERE id = 1;
```

The query should wait behind Session B’s pending lock request. Leave both waiting sessions open and switch to Session D.

## 5. Session D · Find the blockers

```sql
SELECT
    application_name,
    pid,
    state,
    wait_event_type,
    wait_event,
    pg_blocking_pids(pid) AS blockers
FROM pg_stat_activity
WHERE datname = current_database()
  AND application_name IN ('lock-lab-a', 'lock-lab-b', 'lock-lab-c')
ORDER BY application_name;
```

Match the values in `blockers` to the `pid` column. Your process IDs will differ from those in the article.

- **A** should be `idle in transaction`.
- **B** should show a relation-lock wait and list A’s PID.
- **C** should show a relation-lock wait and list B’s PID.

The important detail is that B can block C while B is still waiting for A.

## 6. Release the lock and verify

Go back to Session A and run:

```sql
ROLLBACK;
```

The migration in B should finish, and the query in C should return the row. In Session D, run `\d orders` to check that the `note` column exists.

When you’re finished, exit the `psql` sessions with `\q`. From the project folder, remove the containers and their lab data:

```sh
docker compose down -v
```

Run the startup command again to repeat the lab with a fresh database.

[Subscribe to The Breakdown Files](https://nodarcstudio.substack.com/) for future investigations from Nodarc Studio.
