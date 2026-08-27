//
//  EditExpenseView.swift
//  PayTrack
//
//  Created by bmtech on 27.08.2026.
//

import SwiftUI
import CoreData
import Supabase

struct EditExpenseView: View {

    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var expense: Expense

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(
                keyPath: \Category.name,
                ascending: true
            )
        ]
    )
    private var categories: FetchedResults<Category>

    @State private var title = ""
    @State private var amount = ""
    @State private var date = Date()
    @State private var selectedCategory: Category?

    var body: some View {

        NavigationStack {

            Form {

                Section("expense") {

                    TextField(
                        "expense_name",
                        text: $title
                    )

                    TextField(
                        "amount",
                        text: $amount
                    )
                    .keyboardType(.decimalPad)

                    DatePicker(
                        "date",
                        selection: $date,
                        displayedComponents: .date
                    )
                }

                Section("category") {

                    if categories.isEmpty {

                        Text("create_category_first")
                            .foregroundStyle(.secondary)

                    } else {

                        Picker(
                            "category",
                            selection: $selectedCategory
                        ) {

                            Text("no_category")
                                .tag(Category?.none)

                            ForEach(categories) { category in

                                Text(
                                    LocalizedStringKey(
                                        category.name ?? ""
                                    )
                                )
                                .tag(
                                    Category?.some(category)
                                )
                            }
                        }
                    }
                }

                Button {

                    saveChanges()

                } label: {

                    Text("save")
                        .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("edit_expense")
            .onAppear {

                title = expense.title ?? ""
                amount = String(expense.amount)
                date = expense.date ?? Date()
                selectedCategory = expense.category
            }
        }
    }

    private func saveChanges() {

        guard
            let value = Double(amount),
            !title.isEmpty
        else {
            return
        }

        expense.title = title
        expense.amount = value
        expense.date = date
        expense.category = selectedCategory

        do {

            try context.save()

            AppLogger.shared.info(
                "Expense updated: \(title), amount: \(value)"
            )

            Task {

                do {

                    _ = try await SupabaseManager.shared.client.auth.session

                    AppLogger.shared.info(
                        "Auto update sync started"
                    )

                    await SyncService.shared.syncOneExpense(expense)

                } catch {

                    AppLogger.shared.info(
                        "Auto update sync skipped: no authenticated user"
                    )
                }
            }

            dismiss()

        } catch {

            AppLogger.shared.error(
                "Failed to update expense: \(error.localizedDescription)"
            )
        }
    }
}
