#!/usr/bin/env bash
# Automated tests for M3 Search & Cleaning. Run: bash tests/test_search.sh
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export BASE_DIR DATA_FILE="$T/transactions.csv"
cat > "$DATA_FILE" <<'CSV'
ID,Date,Type,Category,Description,Amount
1,2026-11-01,Income,Salary,Allowance,20000
2,2026-11-02,Expense,Food,Lunch,150
3,2026-11-03,Expense,Travel,Bus,50
4,2026-11-04,Expense,Food,Dinner,200
CSV
source "$BASE_DIR/modules/search.sh"
pass=0; fail=0
ok(){ echo "PASS: $1"; ((pass+=1)); }
bad(){ echo "FAIL: $1"; ((fail+=1)); }

out="$(printf '1\n2026-11-02\n' | search_transactions)"
grep -q 'Lunch' <<< "$out" && ! grep -q 'Dinner' <<< "$out" && ok 'exact date search' || bad 'exact date search'
out="$(printf '2\nfood\n' | search_transactions)"
grep -q 'Lunch' <<< "$out" && grep -q 'Dinner' <<< "$out" && ! grep -q 'Bus' <<< "$out" && ok 'case-insensitive category search' || bad 'category search'
out="$(printf '3\nincome\n' | search_transactions)"
grep -q 'Allowance' <<< "$out" && ! grep -q 'Lunch' <<< "$out" && ok 'type search' || bad 'type search'
out="$(printf '4\n2026-11-02\n2026-11-03\n' | search_transactions)"
grep -q 'Lunch' <<< "$out" && grep -q 'Bus' <<< "$out" && ! grep -q 'Dinner' <<< "$out" && ok 'inclusive date range' || bad 'date range'
out="$(printf '5\n' | search_transactions)"
grep -q 'Allowance' <<< "$out" && grep -q 'Dinner' <<< "$out" && ok 'show all' || bad 'show all'

# Check normalisation and invalid-row removal; cleaning must create a backup.
cat >> "$DATA_FILE" <<'CSV'
 5 , 2026-11-05 , expense , food ,  Snack  , 75.50 
bad,row
6,2026-11-06,Expense,Unknown,Invalid category,20
CSV
printf 'y\n' | clean_transactions >/dev/null
 grep -q '^5,2026-11-05,Expense,Food,Snack,75.50$' "$DATA_FILE" && ok 'cleaner trims and normalises fields' || bad 'normalisation'
[[ "$(wc -l < "$DATA_FILE")" -eq 6 ]] && ok 'cleaner drops malformed/unsupported rows' || bad 'invalid rows'
compgen -G "$DATA_FILE.backup.*" >/dev/null && ok 'cleaner creates backup' || bad 'backup'

echo "Result: $pass passed, $fail failed"
(( fail == 0 ))
