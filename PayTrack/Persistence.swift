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

        let container = NSPersistentContainer(name: "PayTrack")

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

            container.viewContext.perform {
                PersistenceController.setupDefaultCategories(
                    context: container.viewContext
                )
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    private static func setupDefaultCategories(
        context: NSManagedObjectContext
    ) {

        let request: NSFetchRequest<Category> =
            Category.fetchRequest()

        do {

            let categories = try context.fetch(request)

            let defaultNames = [
                "Food",
                "House",
                "Relax",
                "Transport",
                "Other"
            ]

            for name in defaultNames {

                if let category = categories.first(
                    where: { $0.name == name }
                ) {

                    category.isDefault = true

                } else {

                    let category = Category(context: context)

                    category.id = UUID()
                    category.name = name
                    category.icon = "📌"
                    category.isDefault = true
                }
            }

            try context.save()

            AppLogger.shared.info(
                "Default categories checked successfully"
            )

        } catch {

            AppLogger.shared.error(
                "Default categories setup failed: \(error.localizedDescription)"
            )
        }
    }
}
