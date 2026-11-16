# M3 — Search & Cleaning

## Ownership

- Main implementation: `modules/search.sh`
- Automated tests: `tests/test_search.sh`
- Public menu function expected by `main.sh`: `search_transactions`
- Optional maintenance function: `clean_transactions`

## CSV contract

The module reads the shared transaction file through `DATA_FILE` (or defaults to
`data/transactions.csv`). The required header is:

```csv
ID,Date,Type,Category,Description,Amount
```

Descriptions must not contain commas because the team's CSV format is a simple
six-column comma-separated file.

## Features

- Exact date search (`YYYY-MM-DD`)
- Case-insensitive category search
- Income/expense type filter
- Inclusive start/end date range
- Display all transactions
- CSV cleaning: trims whitespace, removes CRLF characters, standardises type and
  category casing, skips malformed/unsupported rows, and creates a timestamped
  backup before replacing the data file

## Run tests

From the project root:

```bash
bash tests/test_search.sh
```

## Integration

`main.sh` should source the module:

```bash
source "$BASE_DIR/modules/search.sh"
```

Then connect the Search & Cleaning menu item to:

```bash
search_transactions
```

If the team wants to expose the cleaner separately, add a menu item calling
`clean_transactions`. Do not source `modules/transactions.sh` twice if the main
program already sources it; this module is intentionally self-contained.
