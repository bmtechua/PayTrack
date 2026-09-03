//
//  SyncService+FullSync.swift
//  PayTrack
//

import Foundation
import CoreData
import Supabase

extension SyncService {

    // MARK: - Current user

    private func currentUserID() async throws -> UUID {

        let user =
            try await client.auth.session.user

        return user.id
    }

    // MARK: - Download remote categories

    private func downloadRemoteCategories(
        for userID: UUID
    ) async throws -> [[String: AnyJSON]] {

        return try await client
            .from("categories")
            .select()
            .eq(
                "user_id",
                value: userID.uuidString
            )
            .execute()
            .value
    }

    // MARK: - Download remote expenses

    private func downloadRemoteExpenses(
        for userID: UUID
    ) async throws -> [[String: AnyJSON]] {

        return try await client
            .from("expenses")
            .select()
            .eq(
                "user_id",
                value: userID.uuidString
            )
            .execute()
            .value
    }

    // MARK: - Merge remote category

    private func mergeRemoteCategory(
        _ remoteCategory: [String: AnyJSON],
        userID: UUID
    ) throws -> Category? {

        guard
            case let .string(idString) =
                remoteCategory["id"],
            let categoryID =
                UUID(uuidString: idString)
        else {
            return nil
        }

        let request:
            NSFetchRequest<Category> =
            Category.fetchRequest()

        request.fetchLimit = 1

        request.predicate =
            NSPredicate(
                format: "id == %@ AND userID == %@",
                categoryID as CVarArg,
                userID as CVarArg
            )

        let category: Category

        if let existing =
            try context.fetch(request).first {

            category = existing

        } else {

            category =
                Category(context: context)

            category.id =
                categoryID

            category.userID =
                userID
        }

        if case let .string(value) =
            remoteCategory["name"] {

            category.name =
                value
        }

        if case let .string(value) =
            remoteCategory["icon"] {

            category.icon =
                value
        }

        if case let .bool(value) =
            remoteCategory["is_default"] {

            category.is_default =
                value
        }

        category.userID =
            userID

        return category
    }

    // MARK: - Merge remote expense

    private func mergeRemoteExpense(
        _ remoteExpense: [String: AnyJSON],
        userID: UUID,
        categoriesByID: [UUID: Category]
    ) throws {

        guard
            case let .string(idString) =
                remoteExpense["id"],
            let expenseID =
                UUID(uuidString: idString)
        else {
            return
        }

        let request:
            NSFetchRequest<Expense> =
            Expense.fetchRequest()

        request.fetchLimit = 1

        request.predicate =
            NSPredicate(
                format: "id == %@ AND userID == %@",
                expenseID as CVarArg,
                userID as CVarArg
            )

        let expense: Expense

        if let existing =
            try context.fetch(request).first {

            expense = existing

        } else {

            expense =
                Expense(context: context)

            expense.id =
                expenseID

            expense.userID =
                userID
        }

        if case let .string(value) =
            remoteExpense["title"] {

            expense.title =
                value
        }

        if let amount =
            remoteExpense["amount"] {

            switch amount {

            case .double(let value):

                expense.amount =
                    value

            case .integer(let value):

                expense.amount =
                    Double(value)

            default:
                break
            }
        }

        if case let .string(value) =
            remoteExpense["date"] {

            let formatter =
                ISO8601DateFormatter()

            if let date =
                formatter.date(from: value) {

                expense.date =
                    date
            }
        }

        if case let .string(value) =
            remoteExpense["merchant_name"] {

            expense.merchantName =
                value
        }

        if case let .string(value) =
            remoteExpense["source"] {

            expense.source =
                value
        }

        if case let .string(value) =
            remoteExpense["transaction_id"] {

            expense.transactionID =
                value
        }

        if case let .string(categoryIDString) =
            remoteExpense["category_id"],
           let categoryID =
            UUID(uuidString: categoryIDString) {

            expense.category =
                categoriesByID[categoryID]

        } else {

            expense.category =
                nil
        }

        expense.userID =
            userID
    }

    // MARK: - Migrate Free categories

    private func migrateFreeCategories(
        to userID: UUID
    ) throws {

        let freeRequest:
            NSFetchRequest<Category> =
            Category.fetchRequest()

        freeRequest.predicate =
            NSPredicate(
                format: "userID == nil"
            )

        let freeCategories =
            try context.fetch(freeRequest)

        guard
            !freeCategories.isEmpty
        else {
            return
        }

        let premiumRequest:
            NSFetchRequest<Category> =
            Category.fetchRequest()

        premiumRequest.predicate =
            NSPredicate(
                format: "userID == %@",
                userID as CVarArg
            )

        let premiumCategories =
            try context.fetch(
                premiumRequest
            )

        for freeCategory
        in freeCategories {

            guard
                let freeName =
                    freeCategory.name?
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ),
                !freeName.isEmpty
            else {

                freeCategory.userID =
                    userID

                continue
            }

            // Find existing Premium category
            // with the same name.
            if let premiumCategory =
                premiumCategories.first(
                    where: {

                        guard
                            let premiumName =
                                $0.name
                        else {
                            return false
                        }

                        return premiumName
                            .trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )
                            .caseInsensitiveCompare(
                                freeName
                            ) == .orderedSame
                    }
                ) {

                let expenseRequest:
                    NSFetchRequest<Expense> =
                    Expense.fetchRequest()

                expenseRequest.predicate =
                    NSPredicate(
                        format: "category == %@",
                        freeCategory
                    )

                let expenses =
                    try context.fetch(
                        expenseRequest
                    )

                for expense
                in expenses {

                    expense.category =
                        premiumCategory

                    expense.userID =
                        userID
                }

                context.delete(
                    freeCategory
                )

            } else {

                // No matching Premium category.
                // Promote the Free category.
                freeCategory.userID =
                    userID
            }
        }

        try context.save()

        AppLogger.shared.info(
            "Free categories migrated to Premium user: \(userID)"
        )
    }

    // MARK: - Migrate Free expenses

    private func migrateFreeExpenses(
        to userID: UUID
    ) throws {

        let request:
            NSFetchRequest<Expense> =
            Expense.fetchRequest()

        request.predicate =
            NSPredicate(
                format: "userID == nil"
            )

        let freeExpenses =
            try context.fetch(request)

        guard
            !freeExpenses.isEmpty
        else {
            return
        }

        for expense
        in freeExpenses {

            expense.userID =
                userID
        }

        try context.save()

        AppLogger.shared.info(
            "Free expenses migrated to Premium user: \(userID)"
        )
    }

    // MARK: - Remove duplicate local categories

    private func removeDuplicateLocalCategories(
        for userID: UUID
    ) throws {

        let request:
            NSFetchRequest<Category> =
            Category.fetchRequest()

        request.predicate =
            NSPredicate(
                format: "userID == %@",
                userID as CVarArg
            )

        request.sortDescriptors = [
            NSSortDescriptor(
                key: "name",
                ascending: true
            )
        ]

        let categories =
            try context.fetch(request)

        let grouped =
            Dictionary(
                grouping: categories
            ) {

                ($0.name ?? "")
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    .lowercased()
            }

        for (_, duplicates)
        in grouped {

            guard
                duplicates.count > 1
            else {
                continue
            }

            // Prefer:
            // 1. default category
            // 2. category with a real icon
            // 3. stable ID

            let primary =
                duplicates
                    .sorted { first, second in

                        if first.is_default !=
                            second.is_default {

                            return first.is_default
                        }

                        let firstIcon =
                            first.icon ?? ""

                        let secondIcon =
                            second.icon ?? ""

                        if firstIcon == "📌",
                           secondIcon != "📌" {

                            return false
                        }

                        if firstIcon != "📌",
                           secondIcon == "📌" {

                            return true
                        }

                        return (
                            first.id?
                                .uuidString
                            ?? ""
                        ) < (
                            second.id?
                                .uuidString
                            ?? ""
                        )
                    }
                    .first!

            for duplicate
            in duplicates
            where duplicate !== primary {

                let expenseRequest:
                    NSFetchRequest<Expense> =
                    Expense.fetchRequest()

                expenseRequest.predicate =
                    NSPredicate(
                        format: "category == %@",
                        duplicate
                    )

                let expenses =
                    try context.fetch(
                        expenseRequest
                    )

                for expense
                in expenses {

                    expense.category =
                        primary

                    expense.userID =
                        userID
                }

                let duplicateName =
                    duplicate.name
                    ?? "No name"

                context.delete(
                    duplicate
                )

                AppLogger.shared.info(
                    "Local duplicate removed: \(duplicateName)"
                )
            }
        }

        if context.hasChanges {

            try context.save()
        }

        AppLogger.shared.info(
            "Local duplicate category cleanup completed"
        )
    }

    // MARK: - Upload local categories

    private func uploadLocalCategories(
        for userID: UUID
    ) async throws {

        let request:
            NSFetchRequest<Category> =
            Category.fetchRequest()

        request.predicate =
            NSPredicate(
                format: "userID == %@",
                userID as CVarArg
            )

        let categories =
            try context.fetch(request)

        for category
        in categories {

            await syncOneCategory(
                category
            )
        }
    }

    // MARK: - Upload local expenses

    private func uploadLocalExpenses(
        for userID: UUID
    ) async throws {

        let request:
            NSFetchRequest<Expense> =
            Expense.fetchRequest()

        request.predicate =
            NSPredicate(
                format: "userID == %@",
                userID as CVarArg
            )

        let expenses =
            try context.fetch(request)

        for expense
        in expenses {

            await syncOneExpense(
                expense
            )
        }
    }

    // MARK: - Local categories by ID

    private func localCategoriesByID(
        for userID: UUID
    ) throws -> [UUID: Category] {

        let request:
            NSFetchRequest<Category> =
            Category.fetchRequest()

        request.predicate =
            NSPredicate(
                format: "userID == %@",
                userID as CVarArg
            )

        let categories =
            try context.fetch(request)

        var result:
            [UUID: Category] =
            [:]

        for category
        in categories {

            if let id =
                category.id {

                result[id] =
                    category
            }
        }

        return result
    }

    // MARK: - Full sync

    func syncAll() async {

        do {

            let userID =
                try await currentUserID()

            AppLogger.shared.info(
                "Full sync started for user: \(userID)"
            )

            // -------------------------------------------------
            // 1. Download Premium categories FIRST.
            // -------------------------------------------------

            let remoteCategories =
                try await downloadRemoteCategories(
                    for: userID
                )

            for remoteCategory
            in remoteCategories {

                _ = try mergeRemoteCategory(
                    remoteCategory,
                    userID: userID
                )
            }

            try context.save()

            // -------------------------------------------------
            // 2. Migrate Free categories.
            // -------------------------------------------------

            try migrateFreeCategories(
                to: userID
            )

            // -------------------------------------------------
            // 3. Migrate Free expenses.
            // -------------------------------------------------

            try migrateFreeExpenses(
                to: userID
            )

            // -------------------------------------------------
            // 4. IMPORTANT:
            // Remove old local Premium duplicates
            // BEFORE uploading anything.
            // -------------------------------------------------

            try removeDuplicateLocalCategories(
                for: userID
            )

            // -------------------------------------------------
            // 5. Upload unique Premium categories.
            // -------------------------------------------------

            try await uploadLocalCategories(
                for: userID
            )

            // -------------------------------------------------
            // 6. Upload Premium expenses.
            // -------------------------------------------------

            try await uploadLocalExpenses(
                for: userID
            )

            // -------------------------------------------------
            // 7. Download Premium expenses.
            // -------------------------------------------------

            let remoteExpenses =
                try await downloadRemoteExpenses(
                    for: userID
                )

            // -------------------------------------------------
            // 8. Build category map.
            // -------------------------------------------------

            let categoriesByID =
                try localCategoriesByID(
                    for: userID
                )

            // -------------------------------------------------
            // 9. Merge remote expenses.
            // -------------------------------------------------

            for remoteExpense
            in remoteExpenses {

                try mergeRemoteExpense(
                    remoteExpense,
                    userID: userID,
                    categoriesByID:
                        categoriesByID
                )
            }

            try context.save()

            AppLogger.shared.info(
                "Full sync completed: \(categoriesByID.count) categories, \(remoteExpenses.count) remote expenses"
            )

        } catch {

            AppLogger.shared.error(
                "Full sync failed: \(error.localizedDescription)"
            )
        }
    }
}
