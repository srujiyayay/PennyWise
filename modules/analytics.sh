#!/bin/bash
# PennyWise - M2: Expense Analytics
# File: modules/analytics.sh
#
# CSV format:
# ID,Date,Type,Category,Description,Amount
#
# main.sh should export DATA_FILE before sourcing this module.
# Example:
# DATA_FILE="$BASE_DIR/data/transactions.csv"
# export BASE_DIR DATA_FILE

# Use the shared DATA_FILE when provided by main.sh.
# Otherwise, use the project's standard data/transactions.csv path.
if [[ -z "${DATA_FILE:-}" ]]; then
    MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    BASE_DIR="$(cd "$MODULE_DIR/.." && pwd)"
    DATA_FILE="$BASE_DIR/data/transactions.csv"
fi

# Calculate and display total income, total expenses, and net balance.
expense_analytics() {
    if [[ ! -f "$DATA_FILE" ]]; then
        echo "No transaction file found: $DATA_FILE"
        return 1
    fi

    awk -F',' '
        NR > 1 {
            amount = $6 + 0

            if ($3 == "Income") {
                income += amount
            } else if ($3 == "Expense") {
                expenses += amount
            }
        }
        END {
            net = income - expenses
            printf "Total Income   : INR %.2f\n", income
            printf "Total Expenses : INR %.2f\n", expenses
            printf "Net Balance    : INR %.2f\n", net
        }
    ' "$DATA_FILE"
}

# Display total expenses grouped by category.
category_summary() {
    if [[ ! -f "$DATA_FILE" ]]; then
        echo "No transaction file found: $DATA_FILE"
        return 1
    fi

    echo "Expense Category Summary"
    echo "------------------------"

    awk -F',' '
        NR > 1 && $3 == "Expense" {
            total[$4] += $6
        }
        END {
            for (category in total) {
                printf "%s,%.2f\n", category, total[category]
            }
        }
    ' "$DATA_FILE" | sort -t',' -k1,1
}

# Display the three categories with the highest expense totals.
top_categories() {
    if [[ ! -f "$DATA_FILE" ]]; then
        echo "No transaction file found: $DATA_FILE"
        return 1
    fi

    echo "Top 3 Spending Categories"
    echo "-------------------------"

    awk -F',' '
        NR > 1 && $3 == "Expense" {
            total[$4] += $6
        }
        END {
            for (category in total) {
                printf "%s,%.2f\n", category, total[category]
            }
        }
    ' "$DATA_FILE" | sort -t',' -k2,2nr | head -n 3
}
