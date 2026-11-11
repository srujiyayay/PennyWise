#!/bin/bash
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
cp "$BASE_DIR/tests/sample_transactions.csv" "$TMP_DIR/transactions.csv"
DATA_FILE="$TMP_DIR/transactions.csv"
export BASE_DIR DATA_FILE
source "$BASE_DIR/modules/transactions.sh"

echo "(Playing with a throwaway copy: $DATA_FILE)"
while true; do
    echo; echo "== M1 TEST MENU =="
    echo "1) Add  2) View  3) Edit  4) Delete  5) Exit"
    read -r -p "Choose: " c || break
    case "$c" in
        1) add_transaction ;;
        2) view_transactions ;;
        3) edit_transaction ;;
        4) delete_transaction ;;
        5) break ;;
        *) echo "Invalid option." ;;
    esac
done
rm -rf "$TMP_DIR"
