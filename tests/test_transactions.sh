#!/bin/bash
# Automated acceptance tests for modules/transactions.sh
# Run from anywhere:  bash tests/test_transactions.sh
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export BASE_DIR DATA_FILE="$T/data/transactions.csv"
source "$BASE_DIR/modules/transactions.sh"

pass=0; fail=0
ok()   { echo "  PASS: $1"; pass=$((pass+1)); }
bad()  { echo "  FAIL: $1"; fail=$((fail+1)); }
expect_fail() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then bad "$d"; else ok "$d"; fi; }
rows() { awk 'NR>1' "$DATA_FILE" | wc -l; }

echo "1. Initialisation"
view_transactions | grep -q "No transactions" && ok "empty file handled" || bad "empty file handled"
[[ "$(head -n1 "$DATA_FILE")" == "$TX_HEADER" && "$(wc -l < "$DATA_FILE")" -eq 1 ]] && ok "exactly one header created" || bad "header"
init_data_file; init_data_file
[[ "$(wc -l < "$DATA_FILE")" -eq 1 ]] && ok "re-init does not duplicate header" || bad "re-init"

echo "2. Add valid rows"
id1="$(tx_append 2026-11-01 Income Salary Allowance 20000)"
id2="$(tx_append 2026-11-02 expense food Lunch 150.50)"
[[ "$id1" == 1 && "$id2" == 2 && "$(rows)" -eq 2 ]] && ok "IDs 1,2 and 2 rows" || bad "valid adds"
grep -q '^2,2026-11-02,Expense,Food,Lunch,150.50$' "$DATA_FILE" && ok "type/category normalised" || bad "normalise"

echo "3. Invalid input rejected"
expect_fail "amount 'abc'"        tx_append 2026-11-03 Expense Food X abc
expect_fail "amount 0"            tx_append 2026-11-03 Expense Food X 0
expect_fail "amount -5"           tx_append 2026-11-03 Expense Food X -5
expect_fail "amount 1.234"        tx_append 2026-11-03 Expense Food X 1.234
expect_fail "date 2026-02-30"     tx_append 2026-02-30 Expense Food X 5
expect_fail "date 02-11-2026"     tx_append 02-11-2026 Expense Food X 5
expect_fail "bad type"            tx_append 2026-11-03 Spend Food X 5
expect_fail "blank category"      tx_append 2026-11-03 Expense "" X 5
expect_fail "unknown category"    tx_append 2026-11-03 Expense Pets X 5
expect_fail "blank description"   tx_append 2026-11-03 Expense Food "   " 5
expect_fail "comma in description" tx_append 2026-11-03 Expense Food "a,b" 5
[[ "$(rows)" -eq 2 ]] && ok "no bad row was written" || bad "bad row written"

echo "4. View"
view_transactions | grep -q "Lunch" && ok "view shows rows" || bad "view"

echo "5. Edit (interactive, piped input)"
before="$(sed -n '2p' "$DATA_FILE")"
printf '2\n\n\n\nLunch at cafe\n200\ny\n' | edit_transaction >/dev/null 2>&1
[[ "$(sed -n '2p' "$DATA_FILE")" == "$before" ]] && ok "row 1 untouched" || bad "row 1 changed"
grep -q '^2,2026-11-02,Expense,Food,Lunch at cafe,200$' "$DATA_FILE" && ok "ID 2 edited" || bad "edit"
cp "$DATA_FILE" "$T/snap"
printf '99\n' | edit_transaction >/dev/null 2>&1
cmp -s "$DATA_FILE" "$T/snap" && ok "edit nonexistent ID: no change" || bad "edit nonexistent"

echo "6. Delete"
printf '99\n' | delete_transaction >/dev/null 2>&1
cmp -s "$DATA_FILE" "$T/snap" && ok "delete nonexistent ID: no change" || bad "delete nonexistent"
printf '2\nn\n' | delete_transaction >/dev/null 2>&1
grep -q '^2,' "$DATA_FILE" && ok "answering n keeps the row" || bad "confirm n"
printf '2\ny\n' | delete_transaction >/dev/null 2>&1
! grep -q '^2,' "$DATA_FILE" && [[ "$(head -n1 "$DATA_FILE")" == "$TX_HEADER" ]] && ok "ID 2 deleted, header kept" || bad "delete"

echo "7. IDs never reused"
id3="$(tx_append 2026-11-04 Expense Travel Bus 50)"
[[ "$id3" == 3 ]] && ok "new ID is 3 (not 2)" || bad "id strategy gave $id3"
printf '3\ny\n' | delete_transaction >/dev/null 2>&1
id4="$(tx_append 2026-11-05 Expense Travel Auto 80)"
[[ "$id4" == 4 ]] && ok "deleting the LAST row does not free its ID" || bad "reuse gave $id4"

echo "8. Robustness"
printf 'garbage\n' > "$T/data/transactions.csv"
expect_fail "file with wrong header is refused" tx_append 2026-11-05 Expense Food X 5
printf '%s\n5,2026-11-01,Income,Other,NoNewline,10' "$TX_HEADER" > "$T/data/transactions.csv"
rm -f "$T/data/.last_id"
tx_append 2026-11-02 Expense Food Tea 20 >/dev/null
[[ "$(wc -l < "$DATA_FILE")" -eq 3 ]] && ok "missing trailing newline handled" || bad "trailing newline"

echo; echo "Result: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
