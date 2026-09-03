//
//  EditExpenseView.swift
//  PayTrack
//

import SwiftUI
import CoreData
import Supabase
import Auth

struct EditExpenseView: View {

    @Environment(\.managedObjectContext)
    private var context

    @Environment(\.dismiss)
    private var dismiss
    
    @ObservedObject
    private var authService = AuthService.shared

    @ObservedObject
    var expense: Expense

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(
                keyPath: \Category.name,
                ascending: true
            )
        ]
    )
    private var categories: FetchedResults<Category>

    private var visibleCategories: [Category] {
        guard let userID = authService.user?.id else {
            return categories.filter { $0.userID == nil }
        }

        return categories.filter { $0.userID == userID }
    }

    @State
    private var title = ""

    @State
    private var amount = ""

    @State
    private var date = Date()

    @State
    private var selectedCategoryID: UUID?

    var body: some View {

        NavigationStack {

            Form {

                // MARK: - Expense

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

                // MARK: - Category

                Section("category") {

                    if visibleCategories.isEmpty {

                        Text("create_category_first")
                            .foregroundStyle(.secondary)

                    } else {

                        Picker(
                            "category",
                            selection: $selectedCategoryID
                        ) {

                            Text("no_category")
                                .tag(UUID?.none)

                            ForEach(visibleCategories) { category in

                                if let categoryID = category.id {

                                    Text(
                                        LocalizedStringKey(
                                            category.name ?? ""
                                        )
                                    )
                                    .tag(
                                        UUID?.some(categoryID)
                                    )
                                }
                            }
                        }
                    }
                }

                // MARK: - Save

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

                amount = String(
                    expense.amount
                )

                date = expense.date ?? Date()

                selectedCategoryID =
                    expense.category?.id
            }
        }
    }

    // MARK: - Save changes

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

        if let categoryID = selectedCategoryID {

            let request: NSFetchRequest<Category> =
                Category.fetchRequest()

            request.fetchLimit = 1

            if let userID = authService.user?.id {
                request.predicate = NSPredicate(
                    format: "id == %@ AND userID == %@",
                    categoryID as CVarArg,
                    userID as CVarArg
                )
            } else {
                request.predicate = NSPredicate(
                    format: "id == %@ AND userID == nil",
                    categoryID as CVarArg
                )
            }

            expense.category =
                try? context.fetch(request).first

        } else {

            expense.category = nil
        }

        do {

            try context.save()

            AppLogger.shared.info(
                "Expense updated: \(title), amount: \(value)"
            )

            if expense.userID != nil {
                Task {
                    do {
                        _ = try await
                            SupabaseManager.shared.client.auth.session

                        AppLogger.shared.info(
                            "Auto update sync started"
                        )

                        await SyncService.shared.syncOneExpense(
                            expense
                        )
                    } catch {
                        AppLogger.shared.info(
                            "Auto update sync skipped: no authenticated user"
                        )
                    }
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
