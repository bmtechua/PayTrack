//
//  CategoriesView.swift
//  PayTrack
//
//  Created by bmtech on 29.06.2026.
//

import SwiftUI
import CoreData
import Supabase

struct CategoriesView: View {

    @Environment(\.managedObjectContext) private var context

    @ObservedObject private var authService = AuthService.shared

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(
                keyPath: \Category.name,
                ascending: true
            )
        ]
    )
    private var categories: FetchedResults<Category>

    @State private var newCategory = ""

    var body: some View {

        NavigationStack {

            VStack {

                // MARK: - Add category

                if authService.user != nil {

                    HStack {

                        TextField(
                            "new_category",
                            text: $newCategory
                        )
                        .textFieldStyle(.roundedBorder)

                        Button {
                            addCategory()
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                    .padding()
                }

                // MARK: - Categories

                List {

                    ForEach(categories) { category in

                        HStack {

                            Text(category.icon ?? "📌")

                            Text(
                                LocalizedStringKey(
                                    category.name ?? ""
                                )
                            )
                        }
                        .deleteDisabled(category.is_default)
                    }
                    .onDelete(
                        perform: deleteCategory
                    )
                }
            }
            .navigationTitle("categories")
        }
    }

    // MARK: - Add category

    private func addCategory() {
        guard !newCategory.isEmpty else {
            return
        }

        guard let user = AuthService.shared.user else {
            AppLogger.shared.error(
                "Cannot add category: user is not logged in"
            )
            return
        }

        let category = Category(context: context)

        category.id = UUID()
        category.name = newCategory
        category.icon = "📌"
        category.is_default = false
        category.userID = user.id

        AppLogger.shared.info(
            "Category added: \(newCategory)"
        )

        save()
        newCategory = ""

        Task {
            await SyncService.shared.syncAll()
        }
    }


    // MARK: - Delete category

    private func deleteCategory(offsets: IndexSet) {
        guard let index = offsets.first else {
            return
        }

        let category = categories[index]

        guard !category.is_default else {
            return
        }

        guard let categoryID = category.id else {
            AppLogger.shared.error(
                "Cannot delete category: category has no ID"
            )
            return
        }

        guard let otherCategory = categories.first(
            where: {
                $0.is_default &&
                $0.name == "Other"
            }
        ) else {
            AppLogger.shared.error(
                "Cannot delete category: Other category not found"
            )
            return
        }

        let categoryName = category.name ?? "unknown"

        // Move expenses to Other
        let expenseRequest: NSFetchRequest<Expense> =
            Expense.fetchRequest()

        expenseRequest.predicate = NSPredicate(
            format: "category == %@",
            category
        )

        do {
            let expenses = try context.fetch(expenseRequest)

            for expense in expenses {
                expense.category = otherCategory
            }

            AppLogger.shared.info(
                "Moved \(expenses.count) expenses from category \(categoryName) to Other"
            )

            // Delete local category
            context.delete(category)

            try context.save()

            AppLogger.shared.info(
                "Category deleted: \(categoryName)"
            )

            // Delete category from Supabase
            Task {
                await SyncService.shared.deleteCategory(
                    id: categoryID,
                    name: categoryName
                )

                await SyncService.shared.syncAll()
            }

        } catch {
            AppLogger.shared.error(
                "Failed to delete category \(categoryName): \(error.localizedDescription)"
            )
        }
    }


    // MARK: - Save

    private func save() {

        do {

            try context.save()

            AppLogger.shared.info(
                "Categories changes saved successfully"
            )

        } catch {

            AppLogger.shared.error(
                "Failed to save category: \(error.localizedDescription)"
            )
        }
    }
}

#Preview {

    CategoriesView()
        .environment(
            \.managedObjectContext,
            PersistenceController.preview.container.viewContext
        )
}
