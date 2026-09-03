//
//  SyncService+Categories.swift
//  PayTrack
//

import Foundation
import CoreData
import Supabase

extension SyncService {

    // MARK: - Sync one category

    func syncOneCategory(_ category: Category) async {

        do {

            let user =
                try await client.auth.session.user

            guard let categoryID = category.id else {

                AppLogger.shared.error(
                    "Category has no ID"
                )

                return
            }

            // This category belongs to the Premium user.
            category.userID = user.id

            let data: [String: AnyJSON] = [

                "id": .string(
                    categoryID.uuidString
                ),

                "user_id": .string(
                    user.id.uuidString
                ),

                "name": .string(
                    category.name ?? ""
                ),

                "icon": category.icon.map {
                    .string($0)
                } ?? .null,

                "is_default": .bool(
                    category.is_default
                )
            ]

            try await client
                .from("categories")
                .upsert(data)
                .execute()

            try context.save()

            AppLogger.shared.info(
                "Category synced successfully: \(category.name ?? "No name")"
            )

        } catch {

            AppLogger.shared.error(
                "Category sync failed: \(error.localizedDescription)"
            )
        }
    }


    // MARK: - Delete category

    func deleteCategory(
        id: UUID,
        name: String
    ) async {

        do {

            let user =
                try await client.auth.session.user

            try await client
                .from("categories")
                .delete()
                .eq(
                    "id",
                    value: id.uuidString
                )
                .eq(
                    "user_id",
                    value: user.id.uuidString
                )
                .execute()

            AppLogger.shared.info(
                "Category deleted from Supabase: \(name)"
            )

        } catch {

            AppLogger.shared.error(
                "Category delete sync failed: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Apply Realtime category INSERT

    func applyRealtimeCategoryInsert(
        _ record: [String: AnyJSON]
    ) {

        guard
            case let .string(idString) =
                record["id"],

            let categoryID =
                UUID(uuidString: idString),

            case let .string(userIDString) =
                record["user_id"],

            let userID =
                UUID(uuidString: userIDString)

        else {

            AppLogger.shared.error(
                "Realtime category INSERT: invalid ID or user_id"
            )

            return
        }

        guard
            UserDefaults.standard.string(
                forKey: "activeUserID"
            ) == userID.uuidString
        else {
            return
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

        do {

            if try context.fetch(request).first != nil {

                AppLogger.shared.info(
                    "Realtime category INSERT skipped: already exists"
                )

                return
            }

            let category =
                Category(context: context)

            category.id =
                categoryID

            category.userID =
                userID

            if case let .string(value) =
                record["name"] {

                category.name =
                    value
            }

            if case let .string(value) =
                record["icon"] {

                category.icon =
                    value
            }

            if case let .bool(value) =
                record["is_default"] {

                category.is_default =
                    value
            }

            try context.save()

            AppLogger.shared.info(
                "Realtime category INSERT applied: \(category.name ?? "No name")"
            )

        } catch {

            AppLogger.shared.error(
                "Realtime category INSERT failed: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Apply Realtime category UPDATE

    func applyRealtimeCategoryUpdate(
        _ record: [String: AnyJSON]
    ) {

        guard
            case let .string(idString) =
                record["id"],

            let categoryID =
                UUID(uuidString: idString),

            case let .string(userIDString) =
                record["user_id"],

            let userID =
                UUID(uuidString: userIDString)

        else {

            AppLogger.shared.error(
                "Realtime category UPDATE: invalid ID or user_id"
            )

            return
        }

        guard
            UserDefaults.standard.string(
                forKey: "activeUserID"
            ) == userID.uuidString
        else {
            return
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

        do {

            guard let category =
                try context.fetch(request).first
            else {

                AppLogger.shared.info(
                    "Realtime category UPDATE: local category not found"
                )

                return
            }

            if case let .string(value) =
                record["name"] {

                category.name =
                    value
            }

            if case let .string(value) =
                record["icon"] {

                category.icon =
                    value
            }

            if case let .bool(value) =
                record["is_default"] {

                category.is_default =
                    value
            }

            category.userID =
                userID

            try context.save()

            AppLogger.shared.info(
                "Realtime category UPDATE applied: \(category.name ?? "No name")"
            )

        } catch {

            AppLogger.shared.error(
                "Realtime category UPDATE failed: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Realtime DELETE

    func applyRealtimeCategoryDelete(
        _ record: [String: AnyJSON]
    ) {

        guard
            case let .string(idString) = record["id"],
            let categoryID = UUID(uuidString: idString),
            case let .string(userIDString) = record["user_id"],
            let userID = UUID(uuidString: userIDString)
        else {
            AppLogger.shared.error(
                "Realtime category DELETE: invalid ID or user_id"
            )
            return
        }

        guard
            UserDefaults.standard.string(
                forKey: "activeUserID"
            ) == userID.uuidString
        else {
            return
        }

        let request: NSFetchRequest<Category> =
            Category.fetchRequest()

        request.fetchLimit = 1

        request.predicate = NSPredicate(
            format: "id == %@ AND userID == %@",
            categoryID as CVarArg,
            userID as CVarArg
        )

        do {

            guard let category =
                try context.fetch(request).first
            else {
                AppLogger.shared.info(
                    "Realtime category DELETE: local category not found"
                )
                return
            }

            let categoryName =
                category.name ?? "No name"

            context.delete(category)

            try context.save()

            AppLogger.shared.info(
                "Realtime category DELETE applied: \(categoryName)"
            )

        } catch {

            AppLogger.shared.error(
                "Realtime category DELETE failed: \(error.localizedDescription)"
            )
        }
    }

}
