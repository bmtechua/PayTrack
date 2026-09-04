import SwiftUI
import CoreData
import Supabase
import Auth

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
    @State private var showAddCategory = false

    @State private var editingCategory: Category?
    @State private var editedCategoryName = ""
    @State private var showEditCategory = false

    private var visibleCategories: [Category] {

        guard let userID = authService.user?.id else {
            return categories.filter { $0.userID == nil }
        }

        return categories.filter {
            $0.userID == userID
        }
    }

    var body: some View {

        NavigationStack {

            List {

                ForEach(visibleCategories) { category in

                    HStack {

                        Text(category.icon ?? "📌")
                            .font(.title3)

                        Text(category.name ?? "")

                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        startEditing(category)
                    }
                    .swipeActions(
                        edge: .trailing,
                        allowsFullSwipe: false
                    ) {

                        // Default categories cannot be deleted
                        if !category.is_default {

                            Button(role: .destructive) {

                                deleteCategory(category)

                            } label: {

                                Label(
                                    NSLocalizedString(
                                        "delete",
                                        comment: ""
                                    ),
                                    systemImage: "trash"
                                )
                            }
                        }
                    }
                }
            }

            .navigationTitle(
                NSLocalizedString(
                    "categories",
                    comment: ""
                )
            )

            .toolbar {

                ToolbarItem(placement: .topBarTrailing) {

                    Button {

                        newCategory = ""
                        showAddCategory = true

                    } label: {

                        Image(systemName: "plus")
                    }
                }
            }

            // MARK: - Add category alert

            .alert(
                NSLocalizedString(
                    "add_category",
                    comment: ""
                ),
                isPresented: $showAddCategory
            ) {

                TextField(
                    NSLocalizedString(
                        "category_name",
                        comment: ""
                    ),
                    text: $newCategory
                )

                Button(
                    NSLocalizedString(
                        "cancel",
                        comment: ""
                    ),
                    role: .cancel
                ) {}

                Button(
                    NSLocalizedString(
                        "add",
                        comment: ""
                    )
                ) {

                    addCategory()
                }

            }

            // MARK: - Edit category alert

            .alert(
                NSLocalizedString(
                    "edit_category",
                    comment: ""
                ),
                isPresented: $showEditCategory
            ) {

                TextField(
                    NSLocalizedString(
                        "category_name",
                        comment: ""
                    ),
                    text: $editedCategoryName
                )

                Button(
                    NSLocalizedString(
                        "cancel",
                        comment: ""
                    ),
                    role: .cancel
                ) {

                    editingCategory = nil
                }

                Button(
                    NSLocalizedString(
                        "save",
                        comment: ""
                    )
                ) {

                    saveEditedCategory()
                }
            }
        }
    }

    // MARK: - Add category

    private func addCategory() {

        let categoryName = newCategory
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !categoryName.isEmpty else {
            return
        }

        let normalizedName = categoryName
            .lowercased()

        // Prevent local duplicate

        let alreadyExists = visibleCategories.contains {

            ($0.name ?? "")
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .lowercased() == normalizedName
        }

        if alreadyExists {

            AppLogger.shared.info(
                "Category already exists: \(categoryName)"
            )

            return
        }

        let category = Category(context: context)

        category.id = UUID()
        category.name = categoryName
        category.icon = "📌"
        category.is_default = false
        category.userID = authService.user?.id

        do {

            try context.save()

            AppLogger.shared.info(
                "Category added: \(categoryName), owner: \(category.userID?.uuidString ?? "Free")"
            )

            if category.userID != nil {

                Task {

                    await SyncService.shared.syncOneCategory(
                        category
                    )
                }
            }

        } catch {

            AppLogger.shared.error(
                "Failed to save category: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Start editing

    private func startEditing(
        _ category: Category
    ) {

        // Default categories cannot be renamed

        guard !category.is_default else {
            return
        }

        editingCategory = category
        editedCategoryName = category.name ?? ""
        showEditCategory = true
    }

    // MARK: - Save edited category

    private func saveEditedCategory() {

        guard let category = editingCategory else {
            return
        }

        let categoryName = editedCategoryName
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !categoryName.isEmpty else {
            return
        }

        let normalizedName = categoryName
            .lowercased()

        // Prevent duplicate name

        let alreadyExists = visibleCategories.contains {

            guard $0.objectID != category.objectID else {
                return false
            }

            return ($0.name ?? "")
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .lowercased() == normalizedName
        }

        if alreadyExists {

            AppLogger.shared.info(
                "Category already exists: \(categoryName)"
            )

            return
        }

        category.name = categoryName

        do {

            try context.save()

            AppLogger.shared.info(
                "Category updated: \(categoryName)"
            )

            if category.userID != nil {

                Task {

                    AppLogger.shared.info(
                        "Auto category update sync started"
                    )

                    await SyncService.shared.syncOneCategory(
                        category
                    )
                }
            }

            editingCategory = nil

        } catch {

            AppLogger.shared.error(
                "Failed to update category: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Delete category

    private func deleteCategory(
        _ category: Category
    ) {

        // Default categories cannot be deleted

        guard !category.is_default else {

            AppLogger.shared.info(
                "Default category cannot be deleted: \(category.name ?? "")"
            )

            return
        }

        let ownerID = category.userID
        let categoryID = category.id
        let categoryName = category.name ?? "No name"

        // Find "Other" in the same ownership scope

        let otherCategory = visibleCategories.first {
            ($0.name ?? "") == "Other"
        }

        let request: NSFetchRequest<Expense> =
            Expense.fetchRequest()

        request.predicate = NSPredicate(
            format: "category == %@",
            category
        )

        do {

            let expenses =
                try context.fetch(request)

            for expense in expenses {

                if let otherCategory {

                    expense.category = otherCategory
                    expense.userID = ownerID
                }
            }

            context.delete(category)

            try context.save()

            AppLogger.shared.info(
                "Category deleted locally: \(categoryName)"
            )

            if let ownerID {

                Task {

                    await SyncService.shared.deleteCategory(
                        id: categoryID ?? UUID(),
                        name: categoryName
                    )
                }

                AppLogger.shared.info(
                    "Premium category delete sync scheduled for user: \(ownerID)"
                )
            }

        } catch {

            AppLogger.shared.error(
                "Failed to delete category: \(error.localizedDescription)"
            )
        }
    }
}

