#!/bin/bash
# =============================================================================
# modules/transactions.sh  -  M1: Transaction management
# Provides: add_transaction, view_transactions, edit_transaction,
#           delete_transaction (+ validation / helper functions)
#
# CSV schema:  ID,Date,Type,Category,Description,Amount
#
# Conventions (agreed contract):
#   * Uses BASE_DIR and DATA_FILE from main.sh. If they are not set (e.g. when
#     testing this file alone) safe defaults are computed. DATA_FILE is never
#     overwritten if already set.
#   * No function calls `exit`. Return code: 0 = success, 1 = failed/cancelled.
#   * Interactive prompts: type  cancel  at any prompt to go back to the menu.
# =============================================================================

if [[ -z "${BASE_DIR:-}" ]]; then
    BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
DATA_FILE="${DATA_FILE:-$BASE_DIR/data/transactions.csv}"

TX_HEADER="ID,Date,Type,Category,Description,Amount"
TX_CATEGORIES=(Food Travel Utilities Education Entertainment Health Other Salary)

# ----------------------------------------------------------------------------
# Small helpers
# ----------------------------------------------------------------------------
_tx_err()  { echo "Error: $*" >&2; }

_trim() {   # strip leading/trailing whitespace and carriage returns
    local s="${1//$'\r'/}"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

_id_file() { printf '%s/.last_id' "$(dirname "$DATA_FILE")"; }

# ----------------------------------------------------------------------------
# 1. Initialisation: create folder + header only if file is missing/empty.
#    Never overwrites existing records.
# ----------------------------------------------------------------------------
init_data_file() {
    local dir
    dir="$(dirname "$DATA_FILE")"
    mkdir -p "$dir" 2>/dev/null || { _tx_err "cannot create folder $dir"; return 1; }

    if [[ ! -s "$DATA_FILE" ]]; then
        printf '%s\n' "$TX_HEADER" > "$DATA_FILE" 2>/dev/null \
            || { _tx_err "cannot create $DATA_FILE"; return 1; }
        return 0
    fi

    local first
    first="$(head -n1 "$DATA_FILE" | tr -d '\r')"
    if [[ "$first" != "$TX_HEADER" ]]; then
        _tx_err "$DATA_FILE does not start with the header: $TX_HEADER"
        return 1
    fi
    return 0
}

# ----------------------------------------------------------------------------
# 2. Validators. Each prints the NORMALISED value on stdout and returns 0 if
#    valid, 1 if not. (Other modules may reuse them.)
# ----------------------------------------------------------------------------
check_date() {              # real calendar date, YYYY-MM-DD
    local d="$1"
    [[ "$d" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || return 1
    [[ "$(date -d "$d" +%Y-%m-%d 2>/dev/null)" == "$d" ]] || return 1
    printf '%s' "$d"
}

check_type() {              # Income / Expense (case-insensitive input)
    case "${1,,}" in
        income|i)  printf 'Income'  ;;
        expense|e) printf 'Expense' ;;
        *) return 1 ;;
    esac
}

check_category() {          # must be in the agreed list (case-insensitive)
    local c
    for c in "${TX_CATEGORIES[@]}"; do
        if [[ "${c,,}" == "${1,,}" ]]; then printf '%s' "$c"; return 0; fi
    done
    return 1
}

check_description() {       # not blank, no commas/newlines, max 60 chars
    local d
    d="$(_trim "$1")"
    [[ -n "$d" ]]            || return 1
    [[ "$d" != *,* ]]        || return 1
    [[ "$d" != *$'\n'* ]]    || return 1
    (( ${#d} <= 60 ))        || return 1
    printf '%s' "$d"
}

check_amount() {            # positive, max 2 decimals
    local a="$1"
    [[ "$a" =~ ^[0-9]+(\.[0-9]{1,2})?$ ]] || return 1
    awk -v a="$a" 'BEGIN { exit !(a + 0 > 0) }' || return 1
    printf '%s' "$a"
}

check_id() { [[ "$1" =~ ^[0-9]+$ ]] && printf '%s' "$((10#$1))"; }

# ----------------------------------------------------------------------------
# 3. ID strategy: next ID = max(highest ID in file, highest ID ever issued) + 1
#    The "highest ever issued" is kept in data/.last_id, so deleting the last
#    row never causes its ID to be reused.
# ----------------------------------------------------------------------------
_max_id_in_file() {
    awk -F, 'NR>1 && $1 ~ /^[0-9]+$/ && $1+0 > m { m = $1+0 } END { printf "%d", m }' "$DATA_FILE"
}

_last_issued_id() {
    local f last=0
    f="$(_id_file)"
    [[ -r "$f" ]] && last="$(tr -d '[:space:]' < "$f")"
    [[ "$last" =~ ^[0-9]+$ ]] || last=0
    echo "$((10#$last))"
}

_bump_last_id() {           # remember that ID $1 has been used
    local cur
    cur="$(_last_issued_id)"
    (( $1 > cur )) && echo "$1" > "$(_id_file)"
    return 0
}

next_id() {
    local a b
    a="$(_max_id_in_file)"
    b="$(_last_issued_id)"
    echo $(( (a > b ? a : b) + 1 ))
}

# ----------------------------------------------------------------------------
# Row lookup / safe rewrite helpers
# ----------------------------------------------------------------------------
_get_row() {                # $1 = id -> prints the CSV row (or nothing)
    awk -F, -v id="$1" 'NR>1 && $1 == id { print; exit }' "$DATA_FILE"
}

_ensure_trailing_newline() {
    if [[ -s "$DATA_FILE" && -n "$(tail -c1 "$DATA_FILE")" ]]; then
        echo >> "$DATA_FILE"
    fi
}

# ----------------------------------------------------------------------------
# tx_append DATE TYPE CATEGORY DESCRIPTION AMOUNT
#   Non-interactive core used by add_transaction (also handy for tests).
#   Validates everything, assigns an ID, appends ONE row. Prints new ID.
# ----------------------------------------------------------------------------
tx_append() {
    init_data_file || return 1
    local d t c ds a id
    d="$(check_date "$1")"          || { _tx_err "invalid date '$1' (use a real date, YYYY-MM-DD)"; return 1; }
    t="$(check_type "$2")"          || { _tx_err "type must be Income or Expense"; return 1; }
    c="$(check_category "$3")"      || { _tx_err "invalid category '$3'"; return 1; }
    ds="$(check_description "$4")"  || { _tx_err "description must be 1-60 chars with no commas"; return 1; }
    a="$(check_amount "$5")"        || { _tx_err "amount must be a positive number with max 2 decimals"; return 1; }

    id="$(next_id)"
    _ensure_trailing_newline
    printf '%s,%s,%s,%s,%s,%s\n' "$id" "$d" "$t" "$c" "$ds" "$a" >> "$DATA_FILE" \
        || { _tx_err "could not write to $DATA_FILE"; return 1; }
    _bump_last_id "$id"
    echo "$id"
}

# ----------------------------------------------------------------------------
# _ask VAR "Prompt" checker "error message" [default]
#   Loops until the checker accepts the input. 'cancel' or EOF -> return 1.
#   If a default is given, pressing Enter keeps it.
# ----------------------------------------------------------------------------
_ask() {
    local -n _out="$1"
    local prompt="$2" checker="$3" errmsg="$4" default="${5:-}" input val
    while true; do
        if ! read -r -p "$prompt" input; then echo; return 1; fi
        input="$(_trim "$input")"
        if [[ "${input,,}" == "cancel" ]]; then return 1; fi
        if [[ -z "$input" && -n "$default" ]]; then input="$default"; fi
        if val="$("$checker" "$input")"; then
            _out="$val"
            return 0
        fi
        echo "  ✗ $errmsg"
    done
}

_category_hint() { local IFS=', '; echo "${TX_CATEGORIES[*]}"; }

# ----------------------------------------------------------------------------
# add_transaction  (interactive)
# ----------------------------------------------------------------------------
add_transaction() {
    init_data_file || return 1
    local v_date v_type v_cat v_desc v_amt id
    echo "----- Add transaction (type 'cancel' to go back) -----"
    _ask v_date "Date (YYYY-MM-DD) [Enter = today, $(date +%F)]: " check_date \
         "Enter a real date like 2026-11-09." "$(date +%F)" || { echo "Cancelled."; return 1; }
    _ask v_type "Type (Income/Expense): " check_type \
         "Type must be Income or Expense." || { echo "Cancelled."; return 1; }
    _ask v_cat "Category ($(_category_hint)): " check_category \
         "Choose one of: $(_category_hint)." || { echo "Cancelled."; return 1; }
    _ask v_desc "Description (no commas): " check_description \
         "Description cannot be blank, contain commas, or exceed 60 characters." || { echo "Cancelled."; return 1; }
    _ask v_amt "Amount (INR): " check_amount \
         "Amount must be a positive number with at most 2 decimals." || { echo "Cancelled."; return 1; }

    id="$(tx_append "$v_date" "$v_type" "$v_cat" "$v_desc" "$v_amt")" || return 1
    echo "✓ Transaction saved with ID $id."
    return 0
}

# ----------------------------------------------------------------------------
# view_transactions
# ----------------------------------------------------------------------------
view_transactions() {
    init_data_file || return 1
    local n
    n="$(awk -F, 'NR>1 && NF>0' "$DATA_FILE" | wc -l)"
    if (( n == 0 )); then
        echo "No transactions recorded yet."
        return 0
    fi
    awk -F, '
        BEGIN {
            fmt = "%-5s %-12s %-9s %-14s %-30s %12s\n"
            for (i = 0; i < 87; i++) line = line "-"
            printf fmt, "ID", "Date", "Type", "Category", "Description", "Amount (INR)"
            print line
        }
        NR > 1 && NF >= 6 { printf fmt, $1, $2, $3, $4, substr($5, 1, 30), sprintf("%.2f", $6); count++ }
        END { print line; printf "%d transaction(s)\n", count }
    ' "$DATA_FILE"
    return 0
}

# Replace the file atomically using a temp file in the same folder
_replace_file_with() {      # $1 = temp file
    mv "$1" "$DATA_FILE" || { rm -f "$1"; _tx_err "could not update $DATA_FILE"; return 1; }
}

_confirm() {                # $1 = question; default NO
    local ans
    read -r -p "$1 [y/N]: " ans || return 1
    [[ "${ans,,}" == "y" || "${ans,,}" == "yes" ]]
}

# ----------------------------------------------------------------------------
# edit_transaction
# ----------------------------------------------------------------------------
edit_transaction() {
    init_data_file || return 1
    local raw id row
    read -r -p "ID to edit (or 'cancel'): " raw || return 1
    raw="$(_trim "$raw")"
    [[ "${raw,,}" == "cancel" ]] && { echo "Cancelled."; return 1; }
    id="$(check_id "$raw")" || { _tx_err "ID must be a whole number."; return 1; }
    row="$(_get_row "$id")"
    [[ -n "$row" ]] || { _tx_err "no transaction with ID $id."; return 1; }

    local _id o_date o_type o_cat o_desc o_amt
    IFS=, read -r _id o_date o_type o_cat o_desc o_amt <<< "$row"
    echo "Current: $row"
    echo "Press Enter to keep the current value, or type 'cancel' to abort."

    local n_date n_type n_cat n_desc n_amt
    _ask n_date "Date [$o_date]: "        check_date        "Enter a real date like 2026-11-09." "$o_date" || { echo "Cancelled."; return 1; }
    _ask n_type "Type [$o_type]: "        check_type        "Type must be Income or Expense."    "$o_type" || { echo "Cancelled."; return 1; }
    _ask n_cat  "Category [$o_cat]: "     check_category    "Choose one of: $(_category_hint)."  "$o_cat"  || { echo "Cancelled."; return 1; }
    _ask n_desc "Description [$o_desc]: " check_description "Blank, commas or >60 chars not allowed." "$o_desc" || { echo "Cancelled."; return 1; }
    _ask n_amt  "Amount [$o_amt]: "       check_amount      "Must be positive, max 2 decimals."  "$o_amt"  || { echo "Cancelled."; return 1; }

    local newrow="$id,$n_date,$n_type,$n_cat,$n_desc,$n_amt"
    echo "New:     $newrow"
    _confirm "Save this change?" || { echo "No changes made."; return 1; }

    local tmp
    tmp="$(mktemp "${DATA_FILE}.XXXXXX")" || { _tx_err "cannot create temp file"; return 1; }
    NEWROW="$newrow" awk -F, -v id="$id" \
        'NR>1 && $1 == id { print ENVIRON["NEWROW"]; next } { print }' "$DATA_FILE" > "$tmp" \
        || { rm -f "$tmp"; return 1; }
    _replace_file_with "$tmp" || return 1
    echo "✓ Transaction $id updated."
    return 0
}

# ----------------------------------------------------------------------------
# delete_transaction
# ----------------------------------------------------------------------------
delete_transaction() {
    init_data_file || return 1
    local raw id row
    read -r -p "ID to delete (or 'cancel'): " raw || return 1
    raw="$(_trim "$raw")"
    [[ "${raw,,}" == "cancel" ]] && { echo "Cancelled."; return 1; }
    id="$(check_id "$raw")" || { _tx_err "ID must be a whole number."; return 1; }
    row="$(_get_row "$id")"
    [[ -n "$row" ]] || { _tx_err "no transaction with ID $id. Nothing deleted."; return 1; }

    echo "About to delete: $row"
    _confirm "Really delete this transaction?" || { echo "Not deleted."; return 1; }

    _bump_last_id "$id"      # so this ID is never reused
    local tmp
    tmp="$(mktemp "${DATA_FILE}.XXXXXX")" || { _tx_err "cannot create temp file"; return 1; }
    awk -F, -v id="$id" 'NR==1 || $1 != id' "$DATA_FILE" > "$tmp" \
        || { rm -f "$tmp"; return 1; }
    _replace_file_with "$tmp" || return 1
    echo "✓ Transaction $id deleted."
    return 0
}
