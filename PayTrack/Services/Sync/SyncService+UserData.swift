//
//  SyncService+UserData.swift
//  PayTrack
//
//  Created by bmtech on 29.08.2026.
//

import Foundation
import CoreData
import Supabase

extension SyncService {

    // MARK: - Prepare local data for user

    func prepareForUser(_ userID: UUID) async {

        let key = "activeUserID"
        let currentUserID = UserDefaults.standard.string(forKey: key)

        if currentUserID == userID.uuidString {
            return
        }

        AppLogger.shared.info(
            "User changed. Clearing local data for previous user"
        )

        do {
            let categoryRequest: NSFetchRequest<Category> =
                Category.fetchRequest()

            let categories = try context.fetch(categoryRequest)

            for category in categories {
                context.delete(category)
            }

            let expenseRequest: NSFetchRequest<Expense> =
                Expense.fetchRequest()

            let expenses = try context.fetch(expenseRequest)

            for expense in expenses {
                context.delete(expense)
            }

            try context.save()

            UserDefaults.standard.set(
                userID.uuidString,
                forKey: key
            )

            AppLogger.shared.info(
                "Local data cleared for new user"
            )

        } catch {
            AppLogger.shared.error(
                "Failed to prepare local data: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Clear Data after logout
    func clearLocalData() async {

        do {

            let categoryRequest: NSFetchRequest<Category> =
                Category.fetchRequest()

            let categories =
                try context.fetch(categoryRequest)

            for category in categories {
                context.delete(category)
            }

            let expenseRequest: NSFetchRequest<Expense> =
                Expense.fetchRequest()

            let expenses =
                try context.fetch(expenseRequest)

            for expense in expenses {
                context.delete(expense)
            }

            try context.save()

            UserDefaults.standard.removeObject(
                forKey: "activeUserID"
            )

            AppLogger.shared.info(
                "Local data cleared after logout"
            )

        } catch {

            AppLogger.shared.error(
                "Failed to clear local data after logout: \(error.localizedDescription)"
            )
        }
    }

}
