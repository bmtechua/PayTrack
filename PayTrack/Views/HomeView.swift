//
//  HomeView.swift
//  PayTrack
//
//  Created by bmtech on 29.06.2026.
//

import SwiftUI
import CoreData
import Charts

struct HomeView: View {

    @State private var monthlyBudget: Double = 5000
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

                    // MARK: - MONTH SWITCHER (SWIPE UI)
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

                    // Swipe gesture
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                if value.translation.width < -50 {
                                    monthOffset += 1
                                }
                                if value.translation.width > 50 {
                                    monthOffset -= 1
                                }
                            }
                    )

                    // MARK: - PIE CHART
                    Text("Витрати по категоріях")
                        .font(.headline)

                    let category = categoryData()

                    if !category.isEmpty {

                        Chart {
                            ForEach(category, id: \.0) { item in
                                SectorMark(
                                    angle: .value("Сума", item.1)
                                )
                                .foregroundStyle(
                                    by: .value("Категорія", item.0)
                                )
                            }
                        }
                        .frame(height: 250)

                    } else {
                        Text("Немає даних")
                            .foregroundStyle(.secondary)
                    }

                    // MARK: - LINE CHART
                    Text("Витрати по днях")
                        .font(.headline)

                    let daily = dailyData()

                    if !daily.isEmpty {

                        Chart {
                            ForEach(daily, id: \.0) { item in

                                LineMark(
                                    x: .value("День", item.0),
                                    y: .value("Сума", item.1)
                                )
                                .interpolationMethod(.catmullRom)

                                PointMark(
                                    x: .value("День", item.0),
                                    y: .value("Сума", item.1)
                                )
                            }
                        }
                        .frame(height: 220)

                    } else {
                        Text("Немає даних")
                            .foregroundStyle(.secondary)
                    }

                    // MARK: - MONTH TOTAL
                    VStack {

                        Text("Цього місяця")
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
                            Text("Бюджет місяця")
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
                        Text("⚠️ Ви перевищили бюджет!")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }

                    // MARK: - STATS
                    HStack {

                        StatCard(
                            title: "Сьогодні",
                            value: String(format: "%.2f грн", todayTotal())
                        )

                        StatCard(
                            title: "Витрат",
                            value: "\(filteredExpenses().count)"
                        )
                    }

                    // MARK: - ADD BUTTON
                    NavigationLink {
                        AddExpenseView()
                    } label: {
                        Label("Додати витрату", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                    }
                }
                .padding()
            }
            .navigationTitle("Головна")
        }
    }

    // MARK: - MONTH OFFSET
    private var selectedMonth: Date {
        Calendar.current.date(
            byAdding: .month,
            value: monthOffset,
            to: Date()
        ) ?? Date()
    }

    private func monthTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "uk_UA")
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

    // MARK: - PIE DATA
    private func categoryData() -> [(String, Double)] {

        let grouped = Dictionary(grouping: filteredExpenses()) { expense in
            expense.category?.name ?? "Без категорії"
        }

        return grouped.map { key, value in
            let total = value.reduce(0) { $0 + $1.amount }
            return (key, total)
        }
    }

    // MARK: - LINE DATA
    private func dailyData() -> [(String, Double)] {

        let calendar = Calendar.current

        let grouped = Dictionary(grouping: filteredExpenses()) { expense in

            guard let date = expense.date else { return "0" }

            let day = calendar.component(.day, from: date)
            return "\(day)"
        }

        let sorted = grouped.sorted {
            Int($0.key) ?? 0 < Int($1.key) ?? 0
        }

        return sorted.map { key, value in
            let total = value.reduce(0) { $0 + $1.amount }
            return (key, total)
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
