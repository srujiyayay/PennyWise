#!/usr/bin/env bash
# =============================================================================
# modules/search.sh - M3: Search and cleaning
# Public functions: search_transactions, clean_transactions
# CSV contract: ID,Date,Type,Category,Description,Amount
# Uses BASE_DIR and DATA_FILE from main.sh / transactions.sh when available.
# Safe to source: no commands are run until a public function is called.
# =============================================================================

if [[ -z "${BASE_DIR:-}" ]]; then
    BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
DATA_FILE="${DATA_FILE:-$BASE_DIR/data/transactions.csv}"

_SEARCH_HEADER='ID,Date,Type,Category,Description,Amount'
_SEARCH_CATEGORIES='Food Travel Utilities Education Entertainment Health Other Salary'

_search_trim() {
    local value="${1//$'\r'/}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

_search_valid_file() {
    if [[ ! -f "$DATA_FILE" ]]; then
        echo "Error: transaction file not found: $DATA_FILE" >&2
        return 1
    fi
    if [[ "$(head -n 1 "$DATA_FILE" | tr -d '\r')" != "$_SEARCH_HEADER" ]]; then
        echo "Error: unexpected CSV header. Expected: $_SEARCH_HEADER" >&2
        return 1
    fi
}

_search_valid_date() {
    [[ "$1" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] &&
        [[ "$(date -d "$1" +%F 2>/dev/null)" == "$1" ]]
}

_search_print_rows() {
    local filter_type="$1" filter_value="$2" end_date="${3:-}"
    local count
    count="$(awk -F, -v mode="$filter_type" -v value="$filter_value" -v end="$end_date" '
        NR > 1 && NF == 6 {
            date=$2; type=tolower($3); category=tolower($4)
            matched=0
            if (mode == "all") matched=1
            else if (mode == "date" && date == value) matched=1
            else if (mode == "category" && category == tolower(value)) matched=1
            else if (mode == "type" && type == tolower(value)) matched=1
            else if (mode == "range" && date >= value && date <= end) matched=1
            if (matched) {
                printf "%-5s %-12s %-9s %-14s %-30s %12.2f\n", $1,$2,$3,$4,substr($5,1,30),$6
                found++
            }
        }
        END { if (!found) exit 1 }
    ' "$DATA_FILE")" || {
        echo "No matching transactions found."
        return 0
    }
    printf '%-5s %-12s %-9s %-14s %-30s %12s\n' 'ID' 'Date' 'Type' 'Category' 'Description' 'Amount (INR)'
    printf '%s\n' '------------------------------------------------------------------------------------------'
    printf '%s\n' "$count"
}

# search_transactions: interactive search menu; supports cancel at each prompt.
search_transactions() {
    _search_valid_file || return 1
    local choice value end
    echo '----- Search transactions -----'
    echo '1) Search by exact date'
    echo '2) Search by category'
    echo '3) Search by type (Income/Expense)'
    echo '4) Search by date range'
    echo '5) Show all transactions'
    read -r -p 'Choose an option (or type cancel): ' choice || return 1
    [[ "${choice,,}" == cancel ]] && return 1

    case "$choice" in
        1)
            read -r -p 'Date (YYYY-MM-DD): ' value || return 1
            [[ "${value,,}" == cancel ]] && return 1
            _search_valid_date "$value" || { echo 'Invalid date. Use a real date in YYYY-MM-DD format.'; return 1; }
            _search_print_rows date "$value" ;;
        2)
            read -r -p "Category ($_SEARCH_CATEGORIES): " value || return 1
            [[ "${value,,}" == cancel ]] && return 1
            value="$(_search_trim "$value")"
            [[ -n "$value" ]] || { echo 'Category cannot be blank.'; return 1; }
            _search_print_rows category "$value" ;;
        3)
            read -r -p 'Type (Income/Expense): ' value || return 1
            [[ "${value,,}" == cancel ]] && return 1
            case "${value,,}" in income|i) value=Income ;; expense|e) value=Expense ;; *) echo 'Type must be Income or Expense.'; return 1 ;; esac
            _search_print_rows type "$value" ;;
        4)
            read -r -p 'Start date (YYYY-MM-DD): ' value || return 1
            [[ "${value,,}" == cancel ]] && return 1
            _search_valid_date "$value" || { echo 'Invalid start date.'; return 1; }
            read -r -p 'End date (YYYY-MM-DD): ' end || return 1
            [[ "${end,,}" == cancel ]] && return 1
            _search_valid_date "$end" || { echo 'Invalid end date.'; return 1; }
            [[ "$value" > "$end" ]] && { echo 'Start date must not be after end date.'; return 1; }
            _search_print_rows range "$value" "$end" ;;
        5) _search_print_rows all '' ;;
        *) echo 'Invalid option. Choose 1-5.'; return 1 ;;
    esac
}

# clean_transactions: normalises whitespace, CRLF, Type and Category casing.
# Invalid/malformed rows are omitted. A timestamped backup is made before write.
clean_transactions() {
    _search_valid_file || return 1
    local answer temp backup
    read -r -p 'Clean and standardise the CSV? A backup will be created. [y/N]: ' answer || return 1
    [[ "${answer,,}" == y || "${answer,,}" == yes ]] || { echo 'Cleaning cancelled.'; return 1; }

    temp="$(mktemp "${DATA_FILE}.clean.XXXXXX")" || { echo 'Error: cannot create temporary file.' >&2; return 1; }
    backup="${DATA_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    if ! cp -p "$DATA_FILE" "$backup"; then
        rm -f "$temp"; echo 'Error: could not create backup.' >&2; return 1
    fi

    awk -F, -v OFS=, -v header="$_SEARCH_HEADER" '
        function trim(s) { gsub(/\r/, "", s); sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
        BEGIN { print header; kept=0; skipped=0 }
        NR == 1 { next }
        NF == 6 {
            for (i=1; i<=6; i++) $i=trim($i)
            if ($1 !~ /^[0-9]+$/ || $2 !~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/ ||
                ($3 !~ /^(Income|income|INCOME|Expense|expense|EXPENSE)$/) ||
                $4 == "" || $5 == "" || $6 !~ /^[0-9]+([.][0-9]{1,2})?$/ || ($6+0)<=0) { skipped++; next }
            $3 = (tolower($3)=="income" ? "Income" : "Expense")
            low=tolower($4)
            if (low=="food") $4="Food"
            else if (low=="travel") $4="Travel"
            else if (low=="utilities") $4="Utilities"
            else if (low=="education") $4="Education"
            else if (low=="entertainment") $4="Entertainment"
            else if (low=="health") $4="Health"
            else if (low=="other") $4="Other"
            else if (low=="salary") $4="Salary"
            else { skipped++; next }
            print $1,$2,$3,$4,$5,$6; kept++; next
        }
        { skipped++ }
        END { printf "%d %d\n", kept, skipped > "/dev/stderr" }
    ' "$DATA_FILE" > "$temp" 2>"${temp}.stats"

    if [[ ! -s "$temp" ]] || ! grep -Fqx "$_SEARCH_HEADER" "$temp"; then
        rm -f "$temp" "${temp}.stats"; echo 'Error: cleaning failed; original file unchanged.' >&2; return 1
    fi
    local stats kept skipped
    stats="$(cat "${temp}.stats")"; read -r kept skipped <<< "$stats"
    rm -f "${temp}.stats"
    if ! mv "$temp" "$DATA_FILE"; then
        rm -f "$temp"; echo 'Error: could not replace CSV; original backup is available.' >&2; return 1
    fi
    echo "Cleaning complete: $kept valid row(s) kept; $skipped invalid row(s) skipped."
    echo "Backup: $backup"
}
