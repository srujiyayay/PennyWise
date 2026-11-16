#!/usr/bin/env bash
# Smoke tests for the improved M2 and M4 modules.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

mkdir -p "$T/data" "$T/output"
export BASE_DIR="$T" DATA_FILE="$T/data/transactions.csv"
export BUDGET_FILE="$T/data/budgets.csv" OUTPUT_DIR="$T/output"

cat > "$DATA_FILE" <<'CSV'
ID,Date,Type,Category,Description,Amount
1,2026-11-01,Income,Salary,Allowance,20000
2,2026-11-02,Expense,Food,Lunch,150.50
3,2026-11-03,Expense,Travel,Bus fare,50
4,2026-11-04,Expense,Utilities,Recharge,299
5,2026-11-05,Income,Other,Freelance,5000
6,2026-11-06,Expense,Food,Dinner,200
7,2026-10-31,Expense,Food,October meal,100
CSV
cat > "$BUDGET_FILE" <<'CSV'
Category,Limit
Food,500
Travel,100
Utilities,300
CSV

source "$ROOT/modules/analytics.sh"
source "$ROOT/modules/reports.sh"

echo "[M2] Overall analytics"
out="$(expense_analytics)"
grep -q 'Total Income   : INR 25000.00' <<< "$out"
grep -q 'Total Expenses : INR 799.50' <<< "$out"
grep -q 'Net Balance    : INR 24200.50' <<< "$out"
echo "PASS: totals and net balance"

out="$(category_summary)"
grep -q '^Food,450.50$' <<< "$out"
grep -q '^Utilities,299.00$' <<< "$out"
echo "PASS: category totals"

out="$(top_categories)"
grep -q 'Food' <<< "$out"
echo "PASS: top categories"

echo "[M4] Monthly report"
printf '2026-11\n' | monthly_report > "$T/report_stdout"
grep -q 'Income:             INR 25000.00' "$T/report_stdout"
grep -q 'Expenses:           INR 699.50' "$T/report_stdout"
grep -q 'Net balance:        INR 24300.50' "$T/report_stdout"
grep -q 'Food' "$T/report_stdout"
grep -q 'Within budget' "$T/report_stdout"
[[ -f "$OUTPUT_DIR/monthly_2026-11.txt" ]]
echo "PASS: monthly report, category breakdown, budget status and file output"

echo "[Validation] Invalid month"
if printf '2026-13\n' | monthly_report >/dev/null 2>&1; then
    echo "FAIL: invalid month accepted" >&2
    exit 1
fi
echo "PASS: invalid month rejected"

echo "[Validation] Malformed transaction row"
cp "$DATA_FILE" "$T/good.csv"
echo 'bad,row' >> "$DATA_FILE"
if expense_analytics >/dev/null 2>&1; then
    echo "FAIL: malformed row accepted" >&2
    exit 1
fi
mv "$T/good.csv" "$DATA_FILE"
echo "PASS: malformed transaction row rejected"

echo "Result: all M2/M4 smoke tests passed"
