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

            for index in offsets {

                let expense = expenses[index]

                AppLogger.shared.info(
                    "Expense deleted: \(expense.title ?? "Unknown"), amount: \(expense.amount)"
                )

                context.delete(expense)
            }

            do {
                try context.save()

            } catch {
                AppLogger.shared.error(
                    "Failed to delete expense: \(error.localizedDescription)"
                )
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
