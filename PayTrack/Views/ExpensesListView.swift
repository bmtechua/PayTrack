//
//  ExpensesListView.swift
//  PayTrack
//

import SwiftUI
import CoreData
import Supabase

struct ExpensesListView: View {

    @Environment(\.managedObjectContext)
    private var context

    @ObservedObject
    private var authService = AuthService.shared

    @ObservedObject
    private var syncService = SyncService.shared

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(
                keyPath: \Expense.date,
                ascending: false
            )
        ],
        animation: .default
    )
    private var expenses: FetchedResults<Expense>

    @State
    private var selectedExpense: Expense?

    // MARK: - Visible Expenses

    private var visibleExpenses: [Expense] {
        guard let userID = authService.user?.id else {
            return expenses.filter {
                $0.userID == nil
            }
        }

        let enabledPlaidAccountIDs = Set(
            syncService.bankAccounts
                .filter { $0.isEnabled }
                .map { $0.plaidAccountID }
        )
        
        AppLogger.shared.info(
            """
            [EXPENSES LIST]
            enabledPlaidAccounts:
            \(enabledPlaidAccountIDs)

            allBankAccounts:
            \(syncService.bankAccounts.map {
                "\($0.name ?? "nil") | \($0.plaidAccountID) | enabled=\($0.isEnabled)"
            })
            """
        )

//        return expenses.filter { expense in
//            guard expense.userID == userID else {
//                return false
//            }
//
//            // Manual / local expense
//            guard expense.source == "plaid" else {
//                return true
//            }
//
//            // Plaid expense without account must be hidden
//            guard let accountID = expense.plaidAccountID else {
//                return false
//            }
//
//            // Show only if its bank account is enabled
//            return enabledPlaidAccountIDs.contains(accountID)
//        }
        
        let userExpenses = expenses.filter {
            $0.userID == userID
        }

        let manualExpenses = userExpenses.filter {
            $0.source != "plaid"
        }

        let plaidExpenses = userExpenses.filter {
            $0.source == "plaid"
        }

        let plaidWithAccount = plaidExpenses.filter {
            $0.plaidAccountID != nil
        }

        let plaidWithoutAccount = plaidExpenses.filter {
            $0.plaidAccountID == nil
        }

        let plaidEnabled = plaidWithAccount.filter {
            guard let accountID = $0.plaidAccountID else {
                return false
            }

            return enabledPlaidAccountIDs.contains(accountID)
        }

        let plaidDisabled = plaidWithAccount.filter {
            guard let accountID = $0.plaidAccountID else {
                return false
            }

            return !enabledPlaidAccountIDs.contains(accountID)
        }

        AppLogger.shared.info(
            """
            [EXPENSES LIST DEBUG]
            CoreData total: \(expenses.count)
            User expenses: \(userExpenses.count)
            Manual: \(manualExpenses.count)
            Plaid: \(plaidExpenses.count)
            Plaid with account: \(plaidWithAccount.count)
            Plaid without account: \(plaidWithoutAccount.count)
            Plaid enabled: \(plaidEnabled.count)
            Plaid disabled/not found: \(plaidDisabled.count)
            Visible expected: \(manualExpenses.count + plaidEnabled.count)

            Enabled account IDs:
            \(enabledPlaidAccountIDs)

            Loaded bank accounts:
            \(syncService.bankAccounts.count)
            """
        )

        return userExpenses.filter { expense in
            guard expense.source == "plaid" else {
                return true
            }

            guard let accountID = expense.plaidAccountID else {
                return false
            }

            return enabledPlaidAccountIDs.contains(accountID)
        }
    }

    // MARK: - Grouped Expenses

    private var groupedExpenses:
        [(date: Date, title: String, expenses: [Expense])] {

        let calendar = Calendar.current

        let grouped =
            Dictionary(
                grouping: visibleExpenses
            ) { expense in
                calendar.startOfDay(
                    for: expense.date ?? Date()
                )
            }
            
            AppLogger.shared.info(
                """
                [EXPENSES GROUP DEBUG]
                Visible expenses: \(visibleExpenses.count)
                Groups: \(grouped.count)
                Group sizes: \(grouped.values.map { $0.count }.sorted(by: >))
                """
            )
            
            let expenseIDs = visibleExpenses.compactMap { $0.id }

            let duplicateIDs = Dictionary(
                grouping: expenseIDs,
                by: { $0 }
            )
            .filter { $1.count > 1 }

            AppLogger.shared.info(
                """
                [EXPENSES ID DEBUG]
                Visible expenses: \(visibleExpenses.count)
                IDs: \(expenseIDs.count)
                Unique IDs: \(Set(expenseIDs).count)
                Duplicate ID groups: \(duplicateIDs.count)
                """
            )

            for (id, ids) in duplicateIDs {
                let duplicateExpenses = visibleExpenses.filter {
                    $0.id == id
                }

                AppLogger.shared.info(
                    """
                    [EXPENSES DUPLICATE ID]
                    id=\(id)
                    count=\(duplicateExpenses.count)
                    titles=\(duplicateExpenses.map { $0.title ?? "nil" })
                    """
                )
            }

        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none

        return grouped
            .sorted { $0.key > $1.key }
            .map { date, expenses in

                let title: String

                if calendar.isDateInToday(date) {

                    title = String(
                        localized: "today"
                    )

                } else if calendar.isDateInYesterday(date) {

                    title = String(
                        localized: "yesterday"
                    )

                } else {

                    title = formatter.string(
                        from: date
                    )
                }

                return (
                    date: date,
                    title: title,
                    expenses: expenses.sorted {
                        ($0.date ?? Date.distantPast)
                        >
                        ($1.date ?? Date.distantPast)
                    }
                )
            }
    }

    // MARK: - Body

    var body: some View {

        NavigationStack {

            List {

                ForEach(
                    groupedExpenses,
                    id: \.date
                ) { group in

                    Section {

                        ForEach(
                            group.expenses,
                            id: \.objectID
                        ) { expense in

                            Button {

                                selectedExpense = expense

                            } label: {

                                ExpenseRowView(
                                    expense: expense,
                                    bankAccounts: syncService.bankAccounts
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { offsets in

                            deleteExpense(
                                offsets: offsets,
                                expenses: group.expenses
                            )
                        }

                    } header: {

                        Text(group.title)
                    }
                }
            }

            .navigationTitle("all_expenses")

            .sheet(
                item: $selectedExpense
            ) { expense in

                EditExpenseView(
                    expense: expense
                )
                .environment(
                    \.managedObjectContext,
                    context
                )
            }
        }
    }

    // MARK: - Delete

    private func deleteExpense(
        offsets: IndexSet,
        expenses: [Expense]
    ) {

        withAnimation {

            for index in offsets {

                let expense = expenses[index]

                guard let expenseID = expense.id else {

                    AppLogger.shared.error(
                        "Cannot delete expense: missing ID"
                    )

                    continue
                }

                let expenseTitle =
                    expense.title ?? "Unknown"

                AppLogger.shared.info(
                    "Expense deleted: \(expenseTitle), amount: \(expense.amount)"
                )

                // Sync only Premium expenses.
                // Free expenses stay local.

                if expense.userID != nil {

                    Task {

                        do {

                            _ = try await
                                SupabaseManager.shared.client
                                .auth
                                .session

                            AppLogger.shared.info(
                                "Auto delete sync started"
                            )

                            await SyncService.shared.deleteExpense(
                                id: expenseID,
                                title: expenseTitle
                            )

                        } catch {

                            AppLogger.shared.info(
                                "Auto delete sync skipped: no authenticated user"
                            )
                        }
                    }
                }

                context.delete(expense)
            }

            do {

                try context.save()

            } catch {

                AppLogger.shared.error(
                    "Failed to delete expense: \(error.localizedDescription)"
                )
            }
        }
    }
}

// MARK: - Expense Row

private struct ExpenseRowView: View {

    @AppStorage("currency")
    private var currency = "UAH"

    @ObservedObject
    var expense: Expense

    let bankAccounts: [BankAccount]

    // MARK: - Bank Account

    private var bankAccount: BankAccount? {

        guard let plaidAccountID = expense.plaidAccountID else {
            return nil
        }

        return bankAccounts.first {
            $0.plaidAccountID == plaidAccountID
        }
    }

    // MARK: - Body

    var body: some View {

        HStack {

            VStack(
                alignment: .leading,
                spacing: 5
            ) {

                Text(
                    expense.title ?? ""
                )
                .font(.headline)

                HStack {

                    Text(
                        expense.category?.icon
                        ?? "📌"
                    )

                    Text(
                        LocalizedStringKey(
                            expense.category?.name
                            ?? "no_category"
                        )
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Text(
                    expense.date ?? Date(),
                    style: .date
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                // Bank account for Plaid expenses

                if let bankAccount {
                    HStack(spacing: 5) {
                        Image(systemName: "building.columns.fill")

                        Text(
                            "\(bankAccount.name ?? "Bank account")" +
                            (bankAccount.mask.map {
                                " ••••\($0)"
                            } ?? "")
                        )
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(
                String(
                    format: "%.2f %@",
                    expense.amount,
                    currency
                )
            )
            .fontWeight(.bold)
        }
    }
}

#Preview {

    ExpensesListView()
        .environment(
            \.managedObjectContext,
            PersistenceController.preview
                .container
                .viewContext
        )
}
