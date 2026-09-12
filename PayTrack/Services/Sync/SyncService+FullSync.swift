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

        let response = try await client
            .from("categories")
            .select()
            .eq(
                "user_id",
                value: userID.uuidString
            )
            .execute()

        return try JSONDecoder().decode(
            [[String: AnyJSON]].self,
            from: response.data
        )
    }

    // MARK: - Download remote expenses

    private func downloadRemoteExpenses(
        for userID: UUID
    ) async throws -> [[String: AnyJSON]] {

        let response = try await client
            .from("expenses")
            .select()
            .eq(
                "user_id",
                value: userID.uuidString
            )
            .execute()

        return try JSONDecoder().decode(
            [[String: AnyJSON]].self,
            from: response.data
        )
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

        let request: NSFetchRequest<Category> =
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

        let remoteTransactionID: String?

        if case let .string(value) =
            remoteExpense["transaction_id"],
            !value.isEmpty {

            remoteTransactionID = value

        } else {

            remoteTransactionID = nil
        }

        // -------------------------------------------------
        // 1. First try to find expense by local ID.
        // -------------------------------------------------

        let idRequest: NSFetchRequest<Expense> =
            Expense.fetchRequest()

        idRequest.fetchLimit = 1

        idRequest.predicate =
            NSPredicate(
                format: "id == %@ AND userID == %@",
                expenseID as CVarArg,
                userID as CVarArg
            )

        var expense =
            try context.fetch(idRequest).first

        // -------------------------------------------------
        // 2. If this is a Plaid transaction,
        //    also search by transactionID.
        // -------------------------------------------------

        if expense == nil,
           let transactionID = remoteTransactionID {

            let transactionRequest:
                NSFetchRequest<Expense> =
                Expense.fetchRequest()

            transactionRequest.fetchLimit = 1

            transactionRequest.predicate =
                NSPredicate(
                    format:
                        "transactionID == %@ AND userID == %@",
                    transactionID,
                    userID as CVarArg
                )

            expense =
                try context.fetch(
                    transactionRequest
                ).first
        }

        // -------------------------------------------------
        // 3. Create new expense only if nothing exists.
        // -------------------------------------------------

        if expense == nil {

            expense =
                Expense(context: context)

            expense?.id =
                expenseID

            expense?.userID =
                userID
        }

        guard let expense else {
            return
        }

        // -------------------------------------------------
        // 4. Update expense data.
        // -------------------------------------------------

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

        if let transactionID =
            remoteTransactionID {

            expense.transactionID =
                transactionID
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

        let freeRequest: NSFetchRequest<Category> =
            Category.fetchRequest()

        freeRequest.predicate =
            NSPredicate(
                format: "userID == nil"
            )

        let freeCategories =
            try context.fetch(freeRequest)

        guard !freeCategories.isEmpty else {
            return
        }

        let premiumRequest: NSFetchRequest<Category> =
            Category.fetchRequest()

        premiumRequest.predicate =
            NSPredicate(
                format: "userID == %@",
                userID as CVarArg
            )

        var premiumCategories =
            try context.fetch(premiumRequest)

        for freeCategory in freeCategories {

            guard
                let freeName =
                    freeCategory.name?
                        .trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ),
                !freeName.isEmpty
            else {
                continue
            }

            // MARK: - Free default category

            if freeCategory.is_default {

                let premiumCategory =
                    premiumCategories.first {

                        guard
                            let premiumName =
                                $0.name
                        else {
                            return false
                        }

                        return premiumName
                            .trimmingCharacters(
                                in:
                                    .whitespacesAndNewlines
                            )
                            .caseInsensitiveCompare(
                                freeName
                            )
                            == .orderedSame
                    }

                let targetCategory: Category

                if let premiumCategory {

                    targetCategory =
                        premiumCategory

                } else {

                    let newPremiumCategory =
                        Category(context: context)

                    newPremiumCategory.id =
                        UUID()

                    newPremiumCategory.name =
                        freeCategory.name

                    newPremiumCategory.icon =
                        freeCategory.icon

                    newPremiumCategory.is_default =
                        freeCategory.is_default

                    newPremiumCategory.userID =
                        userID

                    premiumCategories.append(
                        newPremiumCategory
                    )

                    targetCategory =
                        newPremiumCategory
                }

                let expenseRequest:
                    NSFetchRequest<Expense> =
                    Expense.fetchRequest()

                expenseRequest.predicate =
                    NSPredicate(
                        format:
                            "category == %@",
                        freeCategory
                    )

                let expenses =
                    try context.fetch(
                        expenseRequest
                    )

                for expense in expenses {

                    expense.category =
                        targetCategory

                    expense.userID =
                        userID
                }

                // Free category remains untouched.
                continue
            }

            // MARK: - Existing migration for non-default categories

            let premiumCategory =
                premiumCategories.first {

                    guard
                        let premiumName =
                            $0.name
                    else {
                        return false
                    }

                    return premiumName
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )
                        .caseInsensitiveCompare(
                            freeName
                        )
                        == .orderedSame
                }

            if let premiumCategory {

                let expenseRequest:
                    NSFetchRequest<Expense> =
                    Expense.fetchRequest()

                expenseRequest.predicate =
                    NSPredicate(
                        format:
                            "category == %@",
                        freeCategory
                    )

                let expenses =
                    try context.fetch(
                        expenseRequest
                    )

                for expense in expenses {

                    expense.category =
                        premiumCategory

                    expense.userID =
                        userID
                }

                context.delete(
                    freeCategory
                )

            } else {

                freeCategory.userID =
                    userID
            }
        }

        try context.save()

        AppLogger.shared.info(
            "Free default categories preserved; Premium copies prepared for user: \(userID)",
            category: .sync
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
                format:
                    "userID == nil"
            )

        let freeExpenses =
            try context.fetch(request)

        guard !freeExpenses.isEmpty else {
            return
        }

        for expense in freeExpenses {

            expense.userID =
                userID
        }

        try context.save()

        AppLogger.shared.info(
            "Free expenses migrated to Premium user: \(userID)",
            category: .sync
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
                format:
                    "userID == %@",
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
                        in:
                            .whitespacesAndNewlines
                    )
                    .lowercased()
            }

        for (_, duplicates)
            in grouped {

            guard duplicates.count > 1 else {
                continue
            }

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
                        format:
                            "category == %@",
                        duplicate
                    )

                let expenses =
                    try context.fetch(
                        expenseRequest
                    )

                for expense in expenses {

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
                    "Local duplicate removed: \(duplicateName)",
                    category: .coreData
                )
            }
        }

        if context.hasChanges {
            try context.save()
        }

        AppLogger.shared.info(
            "Local duplicate category cleanup completed",
            category: .coreData
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
                format:
                    "userID == %@",
                userID as CVarArg
            )

        let categories =
            try context.fetch(request)

        for category in categories {

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
                format:
                    "userID == %@",
                userID as CVarArg
            )

        let expenses =
            try context.fetch(request)

        for expense in expenses {

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
                format:
                    "userID == %@",
                userID as CVarArg
            )

        let categories =
            try context.fetch(request)

        var result:
            [UUID: Category] =
            [:]

        for category in categories {

            if let id =
                category.id {

                result[id] =
                    category
            }
        }

        return result
    }

    // MARK: - Remove duplicate Plaid expenses

    private func removeDuplicatePlaidExpenses(
        for userID: UUID
    ) throws {

        let request:
            NSFetchRequest<Expense> =
            Expense.fetchRequest()

        request.predicate =
            NSPredicate(
                format: """
                userID == %@ AND
                transactionID != nil AND
                transactionID != ""
                """,
                userID as CVarArg
            )

        let expenses =
            try context.fetch(request)

        let grouped =
            Dictionary(
                grouping: expenses
            ) { expense in

                expense.transactionID ?? ""
            }

        var removedCount = 0

        for (transactionID, duplicates)
            in grouped {

            guard
                !transactionID.isEmpty,
                duplicates.count > 1
            else {
                continue
            }

            let primary =
                duplicates.sorted {

                    first, second in

                    let firstIsPlaid =
                        first.source == "plaid"

                    let secondIsPlaid =
                        second.source == "plaid"

                    if firstIsPlaid !=
                        secondIsPlaid {

                        return firstIsPlaid
                    }

                    return (
                        first.id?.uuidString ?? ""
                    ) < (
                        second.id?.uuidString ?? ""
                    )
                }
                .first!

            for duplicate
                in duplicates
                where duplicate !== primary {

                context.delete(
                    duplicate
                )

                removedCount += 1

                AppLogger.shared.info(
                    "Duplicate Plaid expense removed: \(duplicate.title ?? "Unknown")",
                    category: .coreData
                )
            }
        }

        if context.hasChanges {
            try context.save()
        }

        AppLogger.shared.info(
            "Duplicate Plaid expense cleanup completed. Removed: \(removedCount)",
            category: .coreData
        )
    }

    // MARK: - Remove remote Plaid Sandbox duplicates

    private func removeRemotePlaidSandboxDuplicates(
        for userID: UUID
    ) async {

        do {

            let response = try await client
                .from("expenses")
                .select(
                    "id,title,amount,date,source,created_at"
                )
                .eq(
                    "user_id",
                    value: userID.uuidString
                )
                .eq(
                    "source",
                    value: "plaid"
                )
                .execute()

            let remoteExpenses =
                try JSONDecoder().decode(
                    [[String: AnyJSON]].self,
                    from: response.data
                )

            var calendar =
                Calendar(
                    identifier: .gregorian
                )

            calendar.timeZone =
                TimeZone(
                    secondsFromGMT: 0
                )!

            let isoFormatter =
                ISO8601DateFormatter()

            isoFormatter.formatOptions = [
                .withInternetDateTime,
                .withFractionalSeconds
            ]

            isoFormatter.timeZone =
                TimeZone(
                    secondsFromGMT: 0
                )

            struct RemotePlaidExpense {

                let id: UUID
                let title: String
                let amount: Double
                let date: Date
                let createdAt: Date?
            }

            var parsedExpenses:
                [RemotePlaidExpense] =
                []

            for record
                in remoteExpenses {

                guard
                    case let .string(idString) =
                        record["id"],
                    let id =
                        UUID(
                            uuidString: idString
                        ),
                    case let .string(title) =
                        record["title"],
                    let amountJSON =
                        record["amount"],
                    case let .string(dateString) =
                        record["date"],
                    let date =
                        isoFormatter.date(
                            from: dateString
                        )
                else {
                    continue
                }

                let amount: Double

                switch amountJSON {

                case .double(let value):

                    amount =
                        value

                case .integer(let value):

                    amount =
                        Double(value)

                default:

                    continue
                }

                var createdAt: Date?

                if case let .string(createdAtString) =
                    record["created_at"] {

                    createdAt =
                        isoFormatter.date(
                            from:
                                createdAtString
                        )
                }

                parsedExpenses.append(
                    RemotePlaidExpense(
                        id: id,
                        title: title,
                        amount: amount,
                        date: date,
                        createdAt: createdAt
                    )
                )
            }

            let grouped =
                Dictionary(
                    grouping:
                        parsedExpenses
                ) { expense in

                    let day =
                        calendar.startOfDay(
                            for:
                                expense.date
                        )

                    let components =
                        calendar.dateComponents(
                            [
                                .year,
                                .month,
                                .day
                            ],
                            from: day
                        )

                    let year =
                        components.year ?? 0

                    let month =
                        components.month ?? 0

                    let dayValue =
                        components.day ?? 0

                    let normalizedTitle =
                        expense.title
                            .trimmingCharacters(
                                in:
                                    .whitespacesAndNewlines
                            )
                            .lowercased()

                    return
                        "\(normalizedTitle)|\(expense.amount)|\(year)-\(month)-\(dayValue)"
                }

            var removedCount = 0

            for (key, duplicates)
                in grouped {

                guard duplicates.count > 1 else {
                    continue
                }

                let sorted =
                    duplicates.sorted {
                        first, second in

                        switch (
                            first.createdAt,
                            second.createdAt
                        ) {

                        case (
                            let firstDate?,
                            let secondDate?
                        ):

                            if firstDate !=
                                secondDate {

                                return firstDate <
                                    secondDate
                            }

                        case (
                            _?,
                            nil
                        ):

                            return true

                        case (
                            nil,
                            _?
                        ):

                            return false

                        default:
                            break
                        }

                        return first.id.uuidString <
                            second.id.uuidString
                    }

                guard let primary =
                    sorted.first
                else {
                    continue
                }

                for duplicate
                    in sorted.dropFirst() {

                    try await client
                        .from("expenses")
                        .delete()
                        .eq(
                            "id",
                            value:
                                duplicate.id.uuidString
                        )
                        .eq(
                            "user_id",
                            value:
                                userID.uuidString
                        )
                        .execute()

                    removedCount += 1

                    AppLogger.shared.info(
                        """
                        [SYNC] Plaid Sandbox remote duplicate removed:
                        title=\(duplicate.title)
                        amount=\(duplicate.amount)
                        date=\(duplicate.date)
                        remoteID=\(duplicate.id.uuidString)
                        keptID=\(primary.id.uuidString)
                        key=\(key)
                        """,
                        category: .sync
                    )
                }
            }

            AppLogger.shared.info(
                "Plaid Sandbox remote duplicate cleanup completed. Removed: \(removedCount)",
                category: .sync
            )

        } catch {

            AppLogger.shared.error(
                "Plaid Sandbox remote duplicate cleanup failed: \(error.localizedDescription)",
                category: .sync
            )
        }
    }

    // MARK: - Sync Plaid expenses

    private func syncPlaidExpenses() async {

        do {

            let user =
                try await client.auth.session.user

            let response =
                try await client
                    .from("bank_connections")
                    .select("id")
                    .eq(
                        "user_id",
                        value:
                            user.id.uuidString
                    )
                    .eq(
                        "status",
                        value: "active"
                    )
                    .limit(1)
                    .execute()

            struct BankConnection: Decodable {

                let id: UUID
            }

            let connections =
                try JSONDecoder().decode(
                    [BankConnection].self,
                    from: response.data
                )

            guard
                let connection =
                    connections.first
            else {

                AppLogger.shared.info(
                    "No active Plaid bank connection",
                    category: .sync
                )

                return
            }

            let expenses =
                try await PlaidExpenseService.shared.fetchExpenses(
                    connectionID:
                        connection.id.uuidString
                            .lowercased()
                )

            AppLogger.shared.info(
                "Plaid expenses received: \(expenses.count)",
                category: .sync
            )

            await importPlaidExpenses(
                expenses
            )

        } catch {

            AppLogger.shared.error(
                "Plaid sync failed: \(error.localizedDescription)",
                category: .sync
            )
        }
    }

    // MARK: - Full sync

    func syncAll() async {

        if let existingTask = fullSyncTask {

            AppLogger.shared.info(
                "Full sync already running. Waiting for existing sync.",
                category: .sync
            )

            await existingTask.value
            return
        }

        let task =
            Task { @MainActor [weak self] in

                guard let self else {
                    return
                }

                await self.performFullSync()
            }

        fullSyncTask =
            task

        await task.value

        fullSyncTask =
            nil
    }

    // MARK: - Perform full sync

    private func performFullSync() async {

        do {

            let userID =
                try await currentUserID()

            AppLogger.shared.info(
                "Full sync started for user: \(userID)",
                category: .sync
            )

            // -------------------------------------------------
            // 1. Download Premium categories FIRST.
            // -------------------------------------------------

            let remoteCategories =
                try await downloadRemoteCategories(
                    for: userID
                )

            try Task.checkCancellation()

            for remoteCategory
                in remoteCategories {

                _ = try mergeRemoteCategory(
                    remoteCategory,
                    userID: userID
                )
            }

            try context.save()

            try Task.checkCancellation()

            // -------------------------------------------------
            // 2. Migrate Free categories.
            // -------------------------------------------------

            try migrateFreeCategories(
                to: userID
            )

            try Task.checkCancellation()

            // -------------------------------------------------
            // 3. Migrate Free expenses.
            // -------------------------------------------------

            try migrateFreeExpenses(
                to: userID
            )

            try Task.checkCancellation()

            // -------------------------------------------------
            // 4. Remove duplicate Plaid expenses.
            // -------------------------------------------------

            try removeDuplicatePlaidExpenses(
                for: userID
            )

            try Task.checkCancellation()

            // -------------------------------------------------
            // 5. Remove old local Premium duplicates.
            // -------------------------------------------------

            try removeDuplicateLocalCategories(
                for: userID
            )

            try Task.checkCancellation()

            // -------------------------------------------------
            // 6. Upload unique Premium categories.
            // -------------------------------------------------

            try await uploadLocalCategories(
                for: userID
            )

            try Task.checkCancellation()

            // -------------------------------------------------
            // 7. Upload Premium expenses.
            // -------------------------------------------------

            try await uploadLocalExpenses(
                for: userID
            )

            try Task.checkCancellation()

            // -------------------------------------------------
            // 8. Download Premium expenses.
            // -------------------------------------------------

            let remoteExpenses =
                try await downloadRemoteExpenses(
                    for: userID
                )

            try Task.checkCancellation()

            // -------------------------------------------------
            // 9. Build category map.
            // -------------------------------------------------

            let categoriesByID =
                try localCategoriesByID(
                    for: userID
                )

            try Task.checkCancellation()

            // -------------------------------------------------
            // 10. Merge remote expenses.
            // -------------------------------------------------

            for remoteExpense
                in remoteExpenses {

                try Task.checkCancellation()

                try mergeRemoteExpense(
                    remoteExpense,
                    userID: userID,
                    categoriesByID:
                        categoriesByID
                )
            }

            try context.save()

            try Task.checkCancellation()

            // -------------------------------------------------
            // 11. Sync Plaid expenses.
            // -------------------------------------------------

            await syncPlaidExpenses()

            try Task.checkCancellation()

            // -------------------------------------------------
            // 12. Remove remote Plaid Sandbox duplicates.
            // -------------------------------------------------

            await removeRemotePlaidSandboxDuplicates(
                for: userID
            )

            try Task.checkCancellation()

            AppLogger.shared.info(
                "Full sync completed: \(categoriesByID.count) categories, \(remoteExpenses.count) remote expenses",
                category: .sync
            )

        } catch is CancellationError {

            AppLogger.shared.info(
                "Full sync cancelled",
                category: .sync
            )

        } catch {

            AppLogger.shared.error(
                "Full sync failed: \(error.localizedDescription)",
                category: .sync
            )
        }
    }
}
