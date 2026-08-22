//
//  HomeView.swift
//  PayTrack
//
//  Created by bmtech on 29.06.2026.
//

import SwiftUI
import CoreData

struct HomeView: View {

    @AppStorage("language")
    private var language = "uk"
    
    @AppStorage("monthlyBudget")
    private var monthlyBudget: Double = 5000
    
    @State private var monthOffset: Int = 0

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(
                keyPath: \Expense.date,
                ascending: false
            )
        ]
    )
    private var expenses: FetchedResults<Expense>

    var body: some View {

        NavigationStack {

            ScrollView {

                VStack(spacing: 20) {

                    // MARK: - MONTH SWITCHER
                    HStack {

                        Button {
                            monthOffset -= 1
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                        }

                        Spacer()

                        Text(monthTitle(selectedMonth))
                            .font(.headline)

                        Spacer()

                        Button {
                            monthOffset += 1
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.title2)
                        }
                    }
                    .padding(.horizontal)

                    // MARK: - MONTH TOTAL
                    VStack {

                        Text("this_month")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Text(String(format: "%.2f грн", monthTotal()))
                            .font(.largeTitle)
                            .bold()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.blue.opacity(0.15))
                    )

                    // MARK: - BUDGET
                    VStack(alignment: .leading, spacing: 10) {

                        HStack {
                            Text("monthly_budget")
                                .font(.headline)

                            Spacer()

                            Text(String(format: "%.0f грн", monthlyBudget))
                                .foregroundStyle(.secondary)
                        }

                        ProgressView(value: budgetProgress())
                            .tint(budgetProgress() > 1 ? .red : .blue)

                        HStack {
                            Text(String(format: "%.0f грн", monthTotal()))
                            Spacer()
                            Text(String(format: "%.0f%%", budgetProgress() * 100))
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.gray.opacity(0.1))
                    )

                    if budgetProgress() > 1 {
                        Text("budget_exceeded")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }

                    // MARK: - STATS
                    HStack {

                        StatCard(
                            title: "today",
                            value: String(format: "%.2f грн", todayTotal())
                        )

                        StatCard(
                            title: "expenses",
                            value: "\(filteredExpenses().count)"
                        )
                    }

                    // MARK: - ADD BUTTON
                    NavigationLink {
                        AddExpenseView()
                    } label: {
                        Label("add_expense", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                    }
                }
                .padding()
            }
            .navigationTitle("home_title")
        }
    }

    // MARK: - MONTH
    private var selectedMonth: Date {
        Calendar.current.date(
            byAdding: .month,
            value: monthOffset,
            to: Date()
        ) ?? Date()
    }

    private func monthTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language)
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }

    // MARK: - FILTER
    private func filteredExpenses() -> [Expense] {

        let calendar = Calendar.current

        return expenses.filter {

            guard let date = $0.date else { return false }

            return calendar.isDate(
                date,
                equalTo: selectedMonth,
                toGranularity: .month
            )
        }
    }

    // MARK: - TOTAL
    private func monthTotal() -> Double {
        filteredExpenses().reduce(0) { $0 + $1.amount }
    }

    private func todayTotal() -> Double {

        filteredExpenses()
            .filter {
                guard let date = $0.date else { return false }
                return Calendar.current.isDateInToday(date)
            }
            .reduce(0) { $0 + $1.amount }
    }

    // MARK: - BUDGET
    private func budgetProgress() -> Double {
        guard monthlyBudget > 0 else { return 0 }
        return monthTotal() / monthlyBudget
    }
}

#Preview {
    HomeView()
}
