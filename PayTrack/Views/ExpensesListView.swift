//
//  ExpensesListView.swift
//  PayTrack
//
//  Created by bmtech on 29.06.2026.
//

import SwiftUI
import CoreData

struct ExpensesListView: View {

    @Environment(\.managedObjectContext) private var context

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(
                keyPath: \Expense.date,
                ascending: false
            )
        ],
        animation: .default
    )
    private var expenses: FetchedResults<Expense>


    var body: some View {

        NavigationStack {

            List {

                ForEach(expenses) { expense in

                    HStack {

                        VStack(alignment: .leading, spacing: 5) {

                            Text(expense.title ?? "")
                                .font(.headline)


                            HStack {

                                Text(
                                    expense.category?.icon ?? "📌"
                                )


                                Text(
                                    expense.category?.name
                                    ?? NSLocalizedString("no_category", comment: "")
                                )
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            }


                            Text(
                                expense.date ?? Date(),
                                style: .date
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        }


                        Spacer()


                        Text(
                            String(
                                format: "%.2f грн",
                                expense.amount
                            )
                        )
                        .fontWeight(.bold)
                    }
                }

                .onDelete(
                    perform: deleteExpense
                )
            }

            .navigationTitle("all_expenses")
        }
    }



    private func deleteExpense(offsets: IndexSet) {

        withAnimation {

            offsets.map {
                expenses[$0]
            }
            .forEach(context.delete)


            do {

                try context.save()

            } catch {

                print(error.localizedDescription)
            }
        }
    }
}


#Preview {

    ExpensesListView()
        .environment(
            \.managedObjectContext,
            PersistenceController.preview.container.viewContext
        )
}
