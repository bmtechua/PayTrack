//
//  SyncService+Categories.swift
//  PayTrack
//
//  Created by bmtech on 29.08.2026.
//

import Foundation
import CoreData
import Supabase

extension SyncService {

    // syncOneCategory
    // MARK: - Sync one category

    func syncOneCategory(_ category: Category) async {

        do {
            let user = try await client.auth.session.user

            guard let categoryID = category.id else {
                AppLogger.shared.error("Category has no ID")
                return
            }

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

            AppLogger.shared.info(
                "Category synced successfully: \(category.name ?? "No name")"
            )

        } catch {
            AppLogger.shared.error(
                "Category sync failed: \(error.localizedDescription)"
            )
        }
    }
    // deleteCategory
    // MARK: - Delete category

    func deleteCategory(id: UUID, name: String) async {

        do {
            let user = try await client.auth.session.user

            try await client
                .from("categories")
                .delete()
                .eq("id", value: id.uuidString)
                .eq("user_id", value: user.id.uuidString)
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
    // createDefaultCategories
    // MARK: - Create default categories

    func createDefaultCategories(for userID: UUID) async {

        let defaultNames = [
            "Food",
            "House",
            "Relax",
            "Transport",
            "Other"
        ]

        do {
            let request: NSFetchRequest<Category> =
                Category.fetchRequest()

            request.predicate = NSPredicate(
                format: "userID == %@",
                userID as CVarArg
            )

            let existingCategories =
                try context.fetch(request)

            for name in defaultNames {

                if existingCategories.contains(
                    where: { $0.name == name }
                ) {
                    continue
                }

                let category = Category(context: context)

                category.id = UUID()
                category.userID = userID
                category.name = name
                category.icon = "📌"
                category.is_default = true
            }

            try context.save()

            AppLogger.shared.info(
                "Default categories created for user: \(userID)"
            )

        } catch {
            AppLogger.shared.error(
                "Failed to create default categories: \(error.localizedDescription)"
            )
        }
    }
    
    // applyRealtimeCategoryInsert
    // MARK: - Apply Realtime category INSERT

    func applyRealtimeCategoryInsert(
        _ record: [String: AnyJSON]
    ) {

        guard
            case let .string(idString) = record["id"],
            let categoryID = UUID(uuidString: idString)
        else {
            AppLogger.shared.error(
                "Realtime category INSERT: invalid ID"
            )
            return
        }

        let request: NSFetchRequest<Category> =
            Category.fetchRequest()

        request.fetchLimit = 1
        request.predicate = NSPredicate(
            format: "id == %@",
            categoryID as CVarArg
        )

        do {

            if try context.fetch(request).first != nil {
                AppLogger.shared.info(
                    "Realtime category INSERT skipped: already exists"
                )
                return
            }

            let category = Category(context: context)

            category.id = categoryID

            if case let .string(value) = record["user_id"] {
                category.userID = UUID(uuidString: value)
            }

            if case let .string(value) = record["name"] {
                category.name = value
            }

            if case let .string(value) = record["icon"] {
                category.icon = value
            }

            if case let .bool(value) = record["is_default"] {
                category.is_default = value
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
    // applyRealtimeCategoryUpdate
    // MARK: - Apply Realtime category UPDATE

    func applyRealtimeCategoryUpdate(
        _ record: [String: AnyJSON]
    ) {

        guard
            case let .string(idString) = record["id"],
            let categoryID = UUID(uuidString: idString)
        else {
            AppLogger.shared.error(
                "Realtime category UPDATE: invalid ID"
            )
            return
        }

        let request: NSFetchRequest<Category> =
            Category.fetchRequest()

        request.fetchLimit = 1
        request.predicate = NSPredicate(
            format: "id == %@",
            categoryID as CVarArg
        )

        do {

            let localCategory = try context.fetch(request).first

            AppLogger.shared.info(
                "Realtime UPDATE id: \(categoryID.uuidString)"
            )

            AppLogger.shared.info(
                "Local category found: \(localCategory != nil)"
            )

            guard let category = localCategory else {

                AppLogger.shared.info(
                    "Realtime category UPDATE: local category not found"
                )

                return
            }

            if case let .string(value) = record["name"] {
                category.name = value
            }

            if case let .string(value) = record["icon"] {
                category.icon = value
            }

            if case let .bool(value) = record["is_default"] {
                category.is_default = value
            }

            if case let .string(value) = record["user_id"] {
                category.userID = UUID(uuidString: value)
            }

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
    // applyRealtimeCategoryDelete
    // MARK: - Apply Realtime category DELETE

    func applyRealtimeCategoryDelete(
        _ record: [String: AnyJSON]
    ) {

        guard
            case let .string(idString) = record["id"],
            let categoryID = UUID(uuidString: idString)
        else {
            AppLogger.shared.error(
                "Realtime category DELETE: invalid ID"
            )
            return
        }

        let request: NSFetchRequest<Category> =
            Category.fetchRequest()

        request.fetchLimit = 1
        request.predicate = NSPredicate(
            format: "id == %@",
            categoryID as CVarArg
        )

        do {

            guard let category = try context.fetch(request).first else {

                AppLogger.shared.info(
                    "Realtime category DELETE: local category not found"
                )

                return
            }

            let name = category.name ?? "No name"

            context.delete(category)

            try context.save()

            AppLogger.shared.info(
                "Realtime category DELETE applied: \(name)"
            )

        } catch {

            AppLogger.shared.error(
                "Realtime category DELETE failed: \(error.localizedDescription)"
            )
        }
    }

}
