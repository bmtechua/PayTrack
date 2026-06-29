//
//  AddExpenseView.swift
//  PayTrack
//
//  Created by bmtech on 29.06.2026.
//

import SwiftUI
import CoreData

struct AddExpenseView: View {

    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss


    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(
                keyPath: \Category.name,
                ascending: true
            )
        ]
    )
    private var categories: FetchedResults<Category>


    @State private var title = ""
    @State private var amount = ""
    @State private var date = Date()

    @State private var selectedCategory: Category?



    var body: some View {

        NavigationStack {

            Form {

                Section("Витрата") {

                    TextField(
                        "Назва",
                        text: $title
                    )


                    TextField(
                        "Сума",
                        text: $amount
                    )
                    .keyboardType(.decimalPad)



                    DatePicker(
                        "Дата",
                        selection: $date,
                        displayedComponents: .date
                    )
                }



                Section("Категорія") {

                    if categories.isEmpty {

                        Text("Створіть категорію спочатку")
                            .foregroundStyle(.secondary)

                    } else {

                        Picker(
                            "Категорія",
                            selection: $selectedCategory
                        ) {

                            Text("Без категорії")
                                .tag(Category?.none)


                            ForEach(categories) { category in

                                Text(
                                    category.name ?? ""
                                )
                                .tag(
                                    Category?.some(category)
                                )
                            }
                        }
                    }
                }



                Button {

                    saveExpense()

                } label: {

                    Text("Зберегти")
                        .frame(maxWidth: .infinity)
                }
            }

            .navigationTitle("Нова витрата")

            .onAppear {

                if selectedCategory == nil {

                    selectedCategory = categories.first
                }
            }
        }
    }



    private func saveExpense() {


        guard
            let value = Double(amount),
            !title.isEmpty

        else {
            return
        }



        let expense = Expense(context: context)


        expense.id = UUID()
        expense.title = title
        expense.amount = value
        expense.date = date

        expense.category = selectedCategory



        do {

            try context.save()

            dismiss()

        } catch {

            print(
                "Save error:",
                error.localizedDescription
            )
        }
    }
}



#Preview {

    AddExpenseView()
        .environment(
            \.managedObjectContext,
            PersistenceController.preview.container.viewContext
        )
}
