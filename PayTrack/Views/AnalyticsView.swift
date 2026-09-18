//
//  AnalyticsView.swift
//  PayTrack
//
//  Created by bmtech on 30.06.2026.
//

import SwiftUI
import CoreData
import Charts
import Auth

struct AnalyticsView: View {

    @AppStorage("language")
    private var language = "uk"

    @AppStorage("currency")
    private var currency = "UAH"

    @ObservedObject
    private var authService = AuthService.shared

    @ObservedObject
    private var syncService = SyncService.shared

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(
                keyPath: \Expense.date,
                ascending: false
            )
        ]
    )
    private var expenses: FetchedResults<Expense>

    @State
    private var monthOffset: Int = 0

    @State
    private var selectedCategory: String?

    @State
    private var showCategoryExpenses = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 25) {

                    monthSwitcher

                    totalCard

                    categoriesSection

                    categoryChartSection

                    dailyChartSection
                }
                .padding()
            }
            .navigationTitle("analytics_title")
        }
        .sheet(isPresented: $showCategoryExpenses) {
            CategoryExpensesView(
                categoryName: selectedCategory ?? "",
                expenses: selectedCategoryExpenses(),
                currency: currency,
                language: language
            )
        }
    }

    // MARK: - MONTH SWITCHER

    private var monthSwitcher: some View {
        HStack {
            Button {
                monthOffset -= 1
            } label: {
                Image(systemName: "chevron.left")
            }

            Spacer()

            Text(monthTitle(selectedMonth))
                .font(.headline)

            Spacer()

            Button {
                monthOffset += 1
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .padding(.horizontal)
    }

    // MARK: - TOTAL

    private var totalCard: some View {
        VStack {
            Text("total_spent")

            Text(
                formatAmount(
                    monthTotal(),
                    currency: currency
                )
            )
            .font(.largeTitle)
            .bold()
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.blue.opacity(0.15))
        )
    }

    // MARK: - CATEGORIES

    private var categoriesSection: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {

            Text("categories")
                .font(.headline)

            let categories = categoryData()

            if categories.isEmpty {

                Text("no_data")
                    .foregroundStyle(.secondary)

            } else {

                LazyVGrid(
                    columns: [
                        GridItem(
                            .flexible(),
                            spacing: 12
                        ),
                        GridItem(
                            .flexible(),
                            spacing: 12
                        )
                    ],
                    spacing: 12
                ) {

                    ForEach(
                        categories,
                        id: \.name
                    ) { category in

                        Button {

                            selectedCategory = category.name
                            showCategoryExpenses = true

                        } label: {

                            VStack(
                                alignment: .leading,
                                spacing: 8
                            ) {

                                Text(category.name)
                                    .font(.headline)
                                    .lineLimit(2)
                                    .multilineTextAlignment(
                                        .leading
                                    )

                                Text(
                                    formatAmount(
                                        category.amount,
                                        currency: currency
                                    )
                                )
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            }
                            .frame(
                                maxWidth: .infinity,
                                minHeight: 75,
                                alignment: .leading
                            )
                            .padding()
                            .background(
                                RoundedRectangle(
                                    cornerRadius: 15
                                )
                                .fill(
                                    Color.gray.opacity(0.1)
                                )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
    }

    // MARK: - CATEGORY CHART

    private var categoryChartSection: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {

            Text("categories")
                .font(.headline)

            let categories = categoryData()

            if categories.isEmpty {

                Text("no_data")
                    .foregroundStyle(.secondary)

            } else {

                Chart {

                    ForEach(
                        categories,
                        id: \.name
                    ) { category in

                        SectorMark(
                            angle: .value(
                                "amount",
                                category.amount
                            )
                        )
                        .foregroundStyle(
                            by: .value(
                                "category",
                                category.name
                            )
                        )
                    }
                }
                .frame(height: 260)
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
    }

    // MARK: - DAILY CHART

    private var dailyChartSection: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {

            Text("by_days")
                .font(.headline)

            let daily = dailyData()

            if daily.isEmpty {

                Text("no_data")
                    .foregroundStyle(.secondary)

            } else {

                Chart {

                    ForEach(
                        daily,
                        id: \.day
                    ) { item in

                        LineMark(
                            x: .value(
                                "day",
                                item.day
                            ),
                            y: .value(
                                "amount",
                                item.amount
                            )
                        )

                        PointMark(
                            x: .value(
                                "day",
                                item.day
                            ),
                            y: .value(
                                "amount",
                                item.amount
                            )
                        )
                    }
                }
                .frame(height: 220)
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
    }

    // MARK: - MONTH

    private var selectedMonth: Date {

        Calendar.current.date(
            byAdding: .month,
            value: monthOffset,
            to: Date()
        ) ?? Date()
    }

    private func monthTitle(
        _ date: Date
    ) -> String {

        let formatter = DateFormatter()

        formatter.locale = Locale(
            identifier: language
        )

        formatter.dateFormat = "LLLL yyyy"

        return formatter.string(
            from: date
        )
    }

    // MARK: - FILTER

    private func filteredExpenses() -> [Expense] {

        let calendar = Calendar.current

        let enabledPlaidAccountIDs = Set(
            syncService.bankAccounts
                .filter { $0.isEnabled }
                .map { $0.plaidAccountID }
        )

        return expenses.filter { expense in

            // Owner filter

            if let userID = authService.user?.id {

                guard expense.userID == userID else {
                    return false
                }

            } else {

                guard expense.userID == nil else {
                    return false
                }
            }

            // Bank account filter

            if expense.source == "plaid" {

                guard
                    let plaidAccountID = expense.plaidAccountID,
                    enabledPlaidAccountIDs.contains(
                        plaidAccountID
                    )
                else {
                    return false
                }
            }

            // Month filter

            guard let date = expense.date else {
                return false
            }

            return calendar.isDate(
                date,
                equalTo: selectedMonth,
                toGranularity: .month
            )
        }
    }

    // MARK: - TOTAL

    private func monthTotal() -> Double {

        filteredExpenses()
            .reduce(0) {
                $0 + $1.amount
            }
    }

    // MARK: - CATEGORY DATA

    private struct CategorySummary {

        let name: String
        let amount: Double
    }

    private func categoryData()
    -> [CategorySummary] {

        let grouped = Dictionary(
            grouping: filteredExpenses()
        ) { expense in

            localizedCategory(
                expense.category?.name,
                language: language
            )
        }

        return grouped
            .map { name, categoryExpenses in

                CategorySummary(
                    name: name,
                    amount: categoryExpenses.reduce(0) {
                        $0 + $1.amount
                    }
                )
            }
            .sorted {
                $0.amount > $1.amount
            }
    }

    // MARK: - SELECTED CATEGORY EXPENSES

    private func selectedCategoryExpenses()
    -> [Expense] {

        guard let selectedCategory else {
            return []
        }

        return filteredExpenses()
            .filter { expense in

                localizedCategory(
                    expense.category?.name,
                    language: language
                ) == selectedCategory
            }
            .sorted {
                ($0.date ?? .distantPast)
                >
                ($1.date ?? .distantPast)
            }
    }

    // MARK: - DAILY DATA

    private struct DailySummary {

        let day: String
        let amount: Double
    }

    private func dailyData()
    -> [DailySummary] {

        let calendar = Calendar.current

        let grouped = Dictionary(
            grouping: filteredExpenses()
        ) { expense in

            guard let date = expense.date else {
                return 0
            }

            return calendar.component(
                .day,
                from: date
            )
        }

        return grouped
            .map { dayNumber, dayExpenses in

                DailySummary(
                    day: String(dayNumber),
                    amount: dayExpenses.reduce(0) {
                        $0 + $1.amount
                    }
                )
            }
            .sorted {

                (Int($0.day) ?? 0)
                <
                (Int($1.day) ?? 0)
            }
    }
}


// MARK: - CATEGORY EXPENSES VIEW

private struct CategoryExpensesView: View {

    let categoryName: String
    let expenses: [Expense]
    let currency: String
    let language: String

    @Environment(\.dismiss)
    private var dismiss

    var body: some View {

        NavigationStack {

            List {

                // MARK: - CATEGORY TOTAL

                Section {

                    VStack(
                        alignment: .leading,
                        spacing: 6
                    ) {

                        Text(categoryName)
                            .font(.title2)
                            .bold()

                        Text(
                            formatAmount(
                                totalAmount(),
                                currency: currency
                            )
                        )
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }

                // MARK: - EXPENSES

                Section {

                    ForEach(
                        expenses,
                        id: \.objectID
                    ) { expense in

                        HStack(
                            alignment: .center,
                            spacing: 12
                        ) {

                            VStack(
                                alignment: .leading,
                                spacing: 4
                            ) {

                                Text(
                                    expenseTitle(
                                        expense
                                    )
                                )
                                .font(.body)
                                .lineLimit(2)

                                if let date = expense.date {

                                    Text(
                                        formattedDate(date)
                                    )
                                    .font(.caption)
                                    .foregroundStyle(
                                        .secondary
                                    )
                                }
                            }

                            Spacer()

                            Text(
                                formatAmount(
                                    expense.amount,
                                    currency: currency
                                )
                            )
                            .font(.body)
                            .bold()
                        }
                        .padding(.vertical, 4)
                    }

                } header: {

                    Text("expenses")
                }
            }
            .navigationTitle(categoryName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {

                ToolbarItem(
                    placement: .topBarTrailing
                ) {

                    Button {

                        dismiss()

                    } label: {

                        Image(
                            systemName: "xmark"
                        )
                    }
                }
            }
            .presentationDetents(
                [.medium, .large]
            )
        }
    }

    // MARK: - EXPENSE TITLE

    private func expenseTitle(
        _ expense: Expense
    ) -> String {

        if let merchant = expense.merchantName,
           !merchant.isEmpty {

            return merchant
        }

        if let title = expense.title,
           !title.isEmpty {

            return title
        }

        return "—"
    }

    // MARK: - TOTAL

    private func totalAmount() -> Double {

        expenses.reduce(0) {
            $0 + $1.amount
        }
    }

    // MARK: - DATE

    private func formattedDate(
        _ date: Date
    ) -> String {

        let formatter = DateFormatter()

        formatter.locale = Locale(
            identifier: language
        )

        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        return formatter.string(
            from: date
        )
    }
}
