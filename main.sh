#!/usr/bin/env bash
# PennyWise - M5: Main Interface, Integration and Application Launcher
#
# Run from the project root:
#   chmod +x main.sh
#   ./main.sh
#
# Expected modules:
#   modules/transactions.sh  (M1)
#   modules/analytics.sh     (M2)
#   modules/search.sh        (M3 - optional until delivered)
#   modules/reports.sh      (M4)

set -o pipefail

# Resolve paths relative to this script, not the user's current directory.
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$BASE_DIR/data"
OUTPUT_DIR="$BASE_DIR/output"
DATA_FILE="${DATA_FILE:-$DATA_DIR/transactions.csv}"
BUDGET_FILE="${BUDGET_FILE:-$DATA_DIR/budgets.csv}"

export BASE_DIR DATA_DIR OUTPUT_DIR DATA_FILE BUDGET_FILE

# Load each available module. M3 may be added later.
load_module() {
    local module_name="$1"
    local module_path="$BASE_DIR/modules/$module_name"

    if [[ -f "$module_path" ]]; then
        # shellcheck source=/dev/null
        source "$module_path" || {
            echo "Warning: could not load $module_name" >&2
            return 1
        }
        return 0
    fi

    echo "Notice: $module_name is not available yet."
    return 1
}

mkdir -p "$DATA_DIR" "$OUTPUT_DIR" || {
    echo "Error: could not create application directories." >&2
    exit 1
}

load_module "transactions.sh" || true
load_module "analytics.sh" || true
load_module "search.sh" || true
load_module "reports.sh" || true

# Initialise the shared transaction file using M1's initializer.
if declare -F init_data_file >/dev/null; then
    init_data_file || {
        echo "Error: transaction data could not be initialized." >&2
        exit 1
    }
else
    echo "Error: M1 transaction module or init_data_file() is unavailable." >&2
    exit 1
fi

pause_screen() {
    echo
    read -r -p "Press Enter to continue..." _
}

show_header() {
    clear 2>/dev/null || true
    echo "=================================================="
    echo "                   PENNYWISE"
    echo "             PERSONAL FINANCE TRACKER"
    echo "=================================================="
    echo
}

show_dashboard() {
    show_header
    echo "                 FINANCIAL DASHBOARD"
    echo "--------------------------------------------------"

    if declare -F expense_analytics >/dev/null; then
        expense_analytics
    else
        echo "Analytics module is unavailable."
    fi

    echo
    if [[ -f "$DATA_FILE" ]]; then
        local count
        count="$(awk 'NR > 1 && NF { n++ } END { print n+0 }' "$DATA_FILE")"
        printf "Recorded transactions: %s\n" "$count"
    else
        echo "No transaction data file found."
    fi
    pause_screen
}

transactions_menu() {
    local choice
    while true; do
        show_header
        echo "TRANSACTION MANAGEMENT"
        echo "1. Add transaction"
        echo "2. View transactions"
        echo "3. Edit transaction"
        echo "4. Delete transaction"
        echo "5. Back to main menu"
        echo
        read -r -p "Choose an option: " choice || return

        case "$choice" in
            1) add_transaction ;;
            2) view_transactions ;;
            3) edit_transaction ;;
            4) delete_transaction ;;
            5) return ;;
            *) echo "Invalid choice. Please select 1-5." ;;
        esac
        pause_screen
    done
}

analytics_menu() {
    local choice
    while true; do
        show_header
        echo "EXPENSE ANALYTICS"
        echo "1. Income, expenses and net balance"
        echo "2. Expense category summary"
        echo "3. Top spending categories"
        echo "4. Back to main menu"
        echo
        read -r -p "Choose an option: " choice || return

        case "$choice" in
            1)
                if declare -F expense_analytics >/dev/null; then expense_analytics
                else echo "Analytics function is unavailable."; fi
                ;;
            2)
                if declare -F category_summary >/dev/null; then category_summary
                else echo "Category summary is unavailable."; fi
                ;;
            3)
                if declare -F top_categories >/dev/null; then top_categories
                else echo "Top categories function is unavailable."; fi
                ;;
            4) return ;;
            *) echo "Invalid choice. Please select 1-4." ;;
        esac
        pause_screen
    done
}

search_menu() {
    local choice
    while true; do
        show_header
        echo "SEARCH AND FILTER"
        echo "1. Search transactions"
        echo "2. Filter by date"
        echo "3. Filter by category"
        echo "4. Reformat transaction data"
        echo "5. Back to main menu"
        echo
        read -r -p "Choose an option: " choice || return

        case "$choice" in
            1)
                if declare -F search_transactions >/dev/null; then search_transactions
                else echo "M3 search module is not available yet."; fi
                ;;
            2)
                if declare -F filter_by_date >/dev/null; then filter_by_date
                else echo "M3 date filter is not available yet."; fi
                ;;
            3)
                if declare -F filter_by_category >/dev/null; then filter_by_category
                else echo "M3 category filter is not available yet."; fi
                ;;
            4)
                if declare -F normalize_transactions >/dev/null; then normalize_transactions
                else echo "M3 formatting function is not available yet."; fi
                ;;
            5) return ;;
            *) echo "Invalid choice. Please select 1-5." ;;
        esac
        pause_screen
    done
}

reports_menu() {
    local choice
    while true; do
        show_header
        echo "REPORTS AND BUDGETING"
        echo "1. Generate monthly report"
        echo "2. Back to main menu"
        echo
        read -r -p "Choose an option: " choice || return

        case "$choice" in
            1)
                if declare -F monthly_report >/dev/null; then monthly_report
                else echo "Monthly reports module is unavailable."; fi
                ;;
            2) return ;;
            *) echo "Invalid choice. Please select 1-2." ;;
        esac
        pause_screen
    done
}

main_menu() {
    local choice
    while true; do
        show_header
        echo "MAIN MENU"
        echo "1. Transaction management"
        echo "2. Expense analytics"
        echo "3. Search and filtering"
        echo "4. Monthly reports and budgeting"
        echo "5. Financial dashboard"
        echo "6. Exit"
        echo
        read -r -p "Choose an option: " choice || break

        case "$choice" in
            1) transactions_menu ;;
            2) analytics_menu ;;
            3) search_menu ;;
            4) reports_menu ;;
            5) show_dashboard ;;
            6)
                echo "Thank you for using PennyWise. Goodbye!"
                return 0
                ;;
            *)
                echo "Invalid choice. Please select 1-6."
                pause_screen
                ;;
        esac
    done
}

main_menu
