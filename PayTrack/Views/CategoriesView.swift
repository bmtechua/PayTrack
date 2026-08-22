//
//  CategoriesView.swift
//  PayTrack
//
//  Created by bmtech on 29.06.2026.
//
import SwiftUI
import CoreData

struct CategoriesView: View {

    @Environment(\.managedObjectContext) private var context


    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Category.name, ascending: true)
        ]
    )
    private var categories: FetchedResults<Category>


    @State private var newCategory = ""


    var body: some View {

        NavigationStack {

            VStack {

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
            //
                Button("TEST CATEGORY ATTRIBUTES") {
                    for category in categories {

                        print("========== CATEGORY ==========")

                        let entity = category.entity

                        for attribute in entity.attributesByName.keys {

                            let value = category.value(
                                forKey: attribute
                            )

                            print("\(attribute):", value as Any)
                        }
                    }
                }
            //
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
                        .deleteDisabled(category.isDefault)
                    }
                    .onDelete(perform: deleteCategory)
                }

            }
            .navigationTitle("categories")
        }
    }



    private func addCategory() {

        guard !newCategory.isEmpty else {
            return
        }


        let category = Category(context: context)

        category.id = UUID()
        category.name = newCategory
        category.icon = "📌"


        save()

        newCategory = ""
    }



    private func deleteCategory(offsets: IndexSet) {

        for index in offsets {

            let category = categories[index]

            guard !category.isDefault else {
                continue
            }

            context.delete(category)
        }

        save()
    }



    private func save() {

        do {

            try context.save()

        } catch {

            print(error.localizedDescription)
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

