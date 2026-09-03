//
//  Persistence.swift
//  PayTrack
//
//  Created by bmtech on 29.06.2026.
//

import CoreData

struct PersistenceController {

    static let shared = PersistenceController()

    @MainActor
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {

        let container = NSPersistentContainer(
            name: "PayTrack"
        )

        if inMemory {
            container.persistentStoreDescriptions.first!.url =
                URL(fileURLWithPath: "/dev/null")
        }

        self.container = container

        container.loadPersistentStores { storeDescription, error in

            if let error = error as NSError? {
                fatalError(
                    "Unresolved error \(error), \(error.userInfo)"
                )
            }

            PersistenceController.createFreeDefaultCategories(
                in: container.viewContext
            )
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    // MARK: - Free default categories

    private static func createFreeDefaultCategories(
        in context: NSManagedObjectContext
    ) {

        let defaultCategories = [
            ("Food", "🍔"),
            ("House", "🏠"),
            ("Relax", "🏖️"),
            ("Transport", "🚗"),
            ("Other", "📌")
        ]

        context.performAndWait {

            do {

                let request: NSFetchRequest<Category> =
                    Category.fetchRequest()

                request.predicate = NSPredicate(
                    format: "userID == nil"
                )

                let existingCategories =
                    try context.fetch(request)

                for (name, icon) in defaultCategories {

                    let exists =
                        existingCategories.contains {
                            $0.name == name
                        }

                    if exists {
                        continue
                    }

                    let category = Category(
                        context: context
                    )

                    category.id = UUID()
                    category.name = name
                    category.icon = icon
                    category.is_default = true
                    category.userID = nil
                }

                if context.hasChanges {
                    try context.save()
                }

            } catch {

                AppLogger.shared.error(
                    "Failed to create Free default categories: \(error.localizedDescription)"
                )
            }
        }
    }
}
