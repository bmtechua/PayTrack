//
//  AddExpenseView.swift
//  PayTrack
//
//  Created by bmtech on 29.06.2026.
//

import SwiftUI
import CoreData
import Supabase

struct AddExpenseView: View {

    @Environment(\.managedObjectContext)
    private var context

    @Environment(\.dismiss)
    private var dismiss

    @ObservedObject
    private var authService = AuthService.shared

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

    private var visibleCategories: [Category] {

        guard let userID = authService.user?.id else {
            // Free mode
            return categories.filter {
                $0.userID == nil
            }
        }

        // Premium mode
        return categories.filter {
            $0.userID == userID
        }
    }

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

                    if visibleCategories.isEmpty {

                        Text("create_category_first")
                            .foregroundStyle(.secondary)

                    } else {

                        Picker(
                            "category",
                            selection: $selectedCategory
                        ) {

                            Text("no_category")
                                .tag(Category?.none)

                            ForEach(visibleCategories) { category in

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

                    saveExpense()

                } label: {

                    Text("save")
                        .frame(maxWidth: .infinity)
                }
            }

            .navigationTitle("new_expense")

            .onAppear {

                if selectedCategory == nil {
                    selectedCategory = visibleCategories.first
                }
            }
        }
    }

    // MARK: - Save

    private func saveExpense() {

        guard
            let value = Double(amount),
            !title.isEmpty
        else {
            return
        }

        let expense = Expense(context: context)

        expense.id = UUID()
        expense.title = title
        expense.amount = value
        expense.date = date
        expense.category = selectedCategory
        expense.source = ExpenseSource.manual.rawValue

        // Free:
        // userID == nil
        //
        // Premium:
        // userID == current user's ID
        expense.userID = authService.user?.id

        let isPremium = expense.userID != nil

        do {

            try context.save()

            AppLogger.shared.info(
                "Expense saved: \(title), amount: \(value), owner: \(isPremium ? "Premium" : "Free")"
            )

            // Sync only Premium expenses.
            if isPremium {

                Task {

                    AppLogger.shared.info(
                        "Auto sync started"
                    )

                    await SyncService.shared.syncOneExpense(
                        expense
                    )
                }
            }

            dismiss()

        } catch {

            AppLogger.shared.error(
                "Failed to save expense: \(error.localizedDescription)"
            )
        }
    }
}

#Preview {

    AddExpenseView()
        .environment(
            \.managedObjectContext,
            PersistenceController.preview.container.viewContext
        )
}
