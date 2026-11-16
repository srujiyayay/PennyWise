#!/usr/bin/env bash

# PennyWise - Monthly reports module (Member 4: Reports)
# Expected transaction CSV columns:
# ID,Date,Type,Category,Description,Amount
# Optional budget CSV columns:
# Category,Limit

# main.sh may define BASE_DIR / DATA_FILE / OUTPUT_DIR before sourcing this file.
if [[ -z "${BASE_DIR:-}" ]]; then
    BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
DATA_FILE="${DATA_FILE:-$BASE_DIR/data/transactions.csv}"
BUDGET_FILE="${BUDGET_FILE:-$BASE_DIR/data/budgets.csv}"
OUTPUT_DIR="${OUTPUT_DIR:-$BASE_DIR/output}"

# Prompt for a month, calculate the totals, and save a report.
monthly_report() {
    local month report_file temp_dir totals_file categories_file
    local income expenses net category amount limit percent status

    if [[ ! -f "$DATA_FILE" ]]; then
        echo "Error: transaction file not found: $DATA_FILE"
        return 1
    fi

    read -r -p "Enter month (YYYY-MM): " month

    # Check both the format and whether the month is a real calendar month.
    if [[ ! "$month" =~ ^[0-9]{4}-(0[1-9]|1[0-2])$ ]] || \
       ! date -d "${month}-01" "+%Y-%m" >/dev/null 2>&1; then
        echo "Invalid month. Please use YYYY-MM (for example, 2026-11)."
        return 1
    fi

    mkdir -p "$OUTPUT_DIR" || {
        echo "Error: could not create output directory: $OUTPUT_DIR"
        return 1
    }

    temp_dir="$(mktemp -d)" || {
        echo "Error: could not create temporary files."
        return 1
    }
    totals_file="$temp_dir/totals"
    categories_file="$temp_dir/categories"

    # AWK sums income and expenses for the selected month and groups expenses
    # by category. The header is skipped; CSV descriptions must not contain commas.
    awk -F',' -v month="$month" -v categories_file="$categories_file" '
        NR == 1 { next }
        substr($2, 1, 7) == month {
            amount = $6 + 0
            if ($3 == "Income") income += amount
            else if ($3 == "Expense") {
                expenses += amount
                category_total[$4] += amount
            }
        }
        END {
            printf "%.2f %.2f\n", income, expenses
            for (category in category_total)
                printf "%s|%.2f\n", category, category_total[category] > categories_file
        }
    ' "$DATA_FILE" > "$totals_file"

    read -r income expenses < "$totals_file"
    income="${income:-0.00}"
    expenses="${expenses:-0.00}"
    net="$(awk -v i="$income" -v e="$expenses" 'BEGIN { printf "%.2f", i-e }')"

    report_file="$OUTPUT_DIR/monthly_${month}.txt"
    {
        echo "PENNYWISE MONTHLY REPORT - $month"
        printf "Income:             INR %s\n" "$income"
        printf "Expenses:           INR %s\n" "$expenses"
        printf "Net:                INR %s\n" "$net"
        echo
        echo "Category breakdown (expenses):"

        if [[ -s "$categories_file" ]]; then
            sort -t'|' -k2,2nr "$categories_file" |
            while IFS='|' read -r category amount; do
                printf "  %-20s INR %s\n" "$category" "$amount"
            done
        else
            echo "  No expense transactions for this month."
        fi

        echo
        echo "Top spending categories:"
        if [[ -s "$categories_file" ]]; then
            sort -t'|' -k2,2nr "$categories_file" | head -n 3 |
            awk -F'|' '{ printf "  %d. %-20s INR %s\n", NR, $1, $2 }'
        else
            echo "  None"
        fi

        # Optional extension: compare this month's category expenses with budgets.
        if [[ -f "$BUDGET_FILE" ]]; then
            echo
            echo "Budget status:"
            if [[ -s "$categories_file" ]]; then
                while IFS='|' read -r category amount; do
                    # Expected budgets.csv format: Category,Limit (one category per row).
                    limit="$(awk -F',' -v wanted="$category" 'NR > 1 && $1 == wanted { print $2; exit }' "$BUDGET_FILE")"
                    if [[ -z "$limit" ]]; then
                        printf "  %-20s No budget set\n" "$category"
                        continue
                    fi
                    if ! awk -v n="$limit" 'BEGIN { exit !(n ~ /^[0-9]+([.][0-9]+)?$/) }'; then
                        printf "  %-20s Invalid budget limit in budgets.csv\n" "$category"
                        continue
                    fi
                    percent="$(awk -v a="$amount" -v l="$limit" 'BEGIN { if (l == 0) print (a > 0 ? "over" : "0"); else printf "%.1f", (a/l)*100 }')"
                    if [[ "$percent" == "over" ]]; then
                        status="Over 100% of budget"
                    elif awk -v p="$percent" 'BEGIN { exit !(p > 100) }'; then
                        status="Over 100% of budget"
                    elif awk -v p="$percent" 'BEGIN { exit !(p >= 80) }'; then
                        status="Warning: at least 80% of budget"
                    else
                        status="Within budget"
                    fi
                    printf "  %-20s INR %s / INR %s (%s%%) - %s\n" \
                        "$category" "$amount" "$limit" "$percent" "$status"
                done < <(sort -t'|' -k1,1 "$categories_file")
            else
                echo "  No expense transactions to compare with budgets."
            fi
        fi

        echo
        echo "Status: Report generated successfully"
    } > "$report_file"

    cat "$report_file"
    echo
    echo "Report saved to: $report_file"
    rm -rf "$temp_dir"
}
