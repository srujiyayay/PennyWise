# PennyWise – Personal Finance Tracker 💰

A simple command-line personal finance tracker built using **Bash scripting and Linux utilities**. PennyWise helps users manage their income and expenses, analyse spending habits, search transactions, and generate monthly financial reports.

This project was developed as a team project to apply concepts of shell scripting, AWK, GREP, SED, file handling, and Git.

## Features

- **Transaction Management:** Add, view, edit, and delete income and expense records.
- **Expense Analytics:** Calculate total income, expenses, balance, and category-wise spending.
- **Search & Filtering:** Search transactions and filter them by date or category.
- **Monthly Reports:** Generate monthly summaries and compare expenses with budget limits.
- **Main Dashboard:** Access all the features through a single menu-driven interface.

## Technologies Used

- Bash Scripting
- AWK
- GREP
- SED
- Ubuntu / Linux
- CSV File Handling
- Git and GitHub

## Project Structure

```text
PennyWise/
│
├── main.sh
│
├── modules/
│   ├── transactions.sh
│   ├── analytics.sh
│   ├── search.sh
│   └── reports.sh
│
├── data/
│   ├── transactions.csv
│   └── budgets.csv
│
├── output/
│
├── tests/
│
└── README.md
```

## Team Members and Responsibilities

| Team Member | Module | Responsibilities |
|---|---|---|
| Harshini | M1 – Transaction Management | Adding, viewing, editing, and deleting transactions |
| Shivakarthik | M2 – Expense Analytics | Calculating expenses, income, balances, and category summaries |
| Aarnavi | M3 – Search & Filtering | Searching and filtering transactions using GREP and SED |
| Ritika | M4 – Reports & Budgeting | Generating monthly reports and comparing expenses with budgets |
| Srujana | M5 – Main Interface & Integration | Developing the main menu, integrating modules, testing, and managing GitHub collaboration |

## Data Storage

PennyWise uses CSV files to store transaction and budget information.

### transactions.csv

```csv
ID,Date,Type,Category,Description,Amount
1,2026-11-01,Income,Salary,Monthly allowance,20000
2,2026-11-02,Expense,Food,Lunch,150
3,2026-11-03,Expense,Travel,Bus fare,50
```

Each transaction contains a unique ID, date, type, category, description, and amount.

### budgets.csv

Stores the spending limits assigned to different categories.

## How to Run

### 1. Clone the repository

```bash
git clone https://github.com/srujiyayay/PennyWise.git
```

### 2. Open the project directory

```bash
cd PennyWise
```

### 3. Give execution permission

```bash
chmod +x main.sh
```

### 4. Run the application

```bash
./main.sh
```

The main menu allows users to access the different modules.

## Testing

We use Bash scripts to test individual modules and check the integrated application.

Run the tests using:

```bash
bash tests/test_transactions.sh
bash tests/test_m2_m4.sh
```

Check script syntax using:

```bash
bash -n main.sh
```

## GitHub Collaboration

We used Git and GitHub to work on different modules independently.

Each member worked on a separate feature branch, and changes were integrated into the `main` branch through Pull Requests.

This helped us manage our code, track changes, and resolve merge conflicts during integration.

## Future Improvements

Some features that could be added in the future include:

- Graphical spending charts.
- Recurring transaction support.
- More advanced budget management.
- Exporting reports to PDF or Excel.
- Improved search and filtering options.

## Conclusion

PennyWise was developed to make basic personal finance management easier while giving us practical experience with Bash scripting, Linux utilities, modular programming, testing, and collaborative software development.

**Repository:** [PennyWise – GitHub](https://github.com/srujiyayay/PennyWise)

**Developed as a team academic project.**
