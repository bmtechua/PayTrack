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

    var body: some View {

        NavigationStack {

            List {

                ForEach(expenses) { expense in

                    Button {
                        selectedExpense = expense
                    } label: {

                        ExpenseRowView(
                            expense: expense
                        )
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(
                    perform: deleteExpense
                )
            }
            .navigationTitle("all_expenses")
            .sheet(item: $selectedExpense) { expense in

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

    private func deleteExpense(offsets: IndexSet) {

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

                Task {

                    do {

                        _ = try await
                            SupabaseManager.shared.client.auth.session

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

    @ObservedObject
    var expense: Expense

    var body: some View {

        HStack {

            VStack(
                alignment: .leading,
                spacing: 5
            ) {

                Text(expense.title ?? "")
                    .font(.headline)

                HStack {

                    Text(
                        expense.category?.icon ?? "📌"
                    )

                    Text(
                        expense.category?.name
                        ?? NSLocalizedString(
                            "no_category",
                            comment: ""
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
            }

            Spacer()

            Text(
                String(
                    format: "%.2f грн",
                    expense.amount
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
            PersistenceController.preview.container.viewContext
        )
}
