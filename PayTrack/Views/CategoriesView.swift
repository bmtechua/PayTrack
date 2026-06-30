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
                        "Нова категорія",
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


                List {

                    ForEach(categories) { category in

                        HStack {

                            Text(category.icon ?? "📌")

                            Text(category.name ?? "")
                        }
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

        offsets.map { categories[$0] }
            .forEach(context.delete)

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

