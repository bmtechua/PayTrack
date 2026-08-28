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
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
    }

}
