//
//  AnalyticsView.swift
//  PayTrack
//
//  Created by bmtech on 30.06.2026.
//

import SwiftUI
import CoreData
import Charts


struct AnalyticsView: View {

    @AppStorage("language")
    private var language = "uk"
    
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(
                keyPath: \Expense.date,
                ascending: false
            )
        ]
    )
    private var expenses: FetchedResults<Expense>


    @State private var monthOffset: Int = 0


    var body: some View {

        NavigationStack {

            ScrollView {

                VStack(spacing: 25) {


                    // MARK: - MONTH SWITCHER

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



                    // MARK: - TOTAL

                    VStack {

                        Text("total_spent")

                        Text(
                            String(
                                format: "%.2f грн",
                                monthTotal()
                            )
                        )
                        .font(.largeTitle)
                        .bold()

                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(
                            cornerRadius: 20
                        )
                        .fill(.blue.opacity(0.15))
                    )



                    // MARK: - CATEGORY CHART


                    Text("categories")
                        .font(.headline)


                    let categories = categoryData()


                    if !categories.isEmpty {


                        Chart {

                            ForEach(
                                categories,
                                id: \.0
                            ) { item in


                                SectorMark(

                                    angle:
                                            .value("amount", item.1)
                                )

                                .foregroundStyle(
                                    by:
                                            .value("category", item.0)
                                )

                            }
                        }

                        .frame(height: 260)



                    } else {

                        Text("no_data")
                            .foregroundStyle(.secondary)
                    }





                    // MARK: - DAILY CHART


                    Text("by_days")
                        .font(.headline)



                    let daily = dailyData()



                    if !daily.isEmpty {


                        Chart {


                            ForEach(
                                daily,
                                id: \.0
                            ) { item in


                                LineMark(

                                    x:
                                            .value("day", item.0),


                                    y:
                                            .value("amount", item.1)
                                )


                                PointMark(

                                    x:
                                            .value("day", item.0),


                                    y:
                                            .value("amount", item.1)                                )

                            }
                        }

                        .frame(height:220)


                    }




                    // MARK: - INSIGHT


                    if let top = topCategory() {


                        VStack(alignment:.leading) {


                            Text("top_category")
                                .font(.headline)


                            Text(
                                "\(top.name) — \(String(format:"%.2f", top.amount)) грн"
                            )

                        }

                        .frame(maxWidth:.infinity,
                               alignment:.leading)

                        .padding()

                        .background(
                            RoundedRectangle(
                                cornerRadius:15
                            )
                            .fill(
                                Color.gray.opacity(0.1)
                            )
                        )
                    }



                }

                .padding()

            }

            .navigationTitle("analytics_title")

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


    private func filteredExpenses()
    -> [Expense] {


        let calendar =
        Calendar.current


        return expenses.filter {


            guard let date =
                    $0.date
            else {
                return false
            }


            return calendar.isDate(
                date,
                equalTo:selectedMonth,
                toGranularity:.month
            )

        }

    }




    // MARK: - TOTAL


    private func monthTotal()
    -> Double {


        filteredExpenses()
            .reduce(0) {
                $0 + $1.amount
            }

    }





    // MARK: - CATEGORY DATA


    private func categoryData()
    -> [(String,Double)] {


        let grouped =
        Dictionary(
            grouping:
                filteredExpenses()
        ) {


            $0.category?.name
            ?? "Без категорії"

        }



        return grouped.map {


            (
                $0.key,

                $0.value.reduce(0){
                    $0 + $1.amount
                }

            )

        }

    }





    // MARK: - DAILY DATA


    private func dailyData()
    -> [(String,Double)] {


        let calendar =
        Calendar.current


        let grouped =
        Dictionary(
            grouping:
                filteredExpenses()
        ) {


            guard let date =
                    $0.date
            else {
                return "0"
            }


            return String(
                calendar.component(
                    .day,
                    from:date
                )
            )

        }




        return grouped
            .sorted {
                Int($0.key)!
                <
                Int($1.key)!
            }

            .map {


                (
                    $0.key,

                    $0.value.reduce(0){
                        $0 + $1.amount
                    }

                )

            }

    }





    // MARK: - TOP CATEGORY


    private func topCategory()
    -> (name:String, amount:Double)? {


        categoryData()
            .max {
                $0.1 < $1.1
            }

            .map {

                (
                    name:$0.0,
                    amount:$0.1
                )

            }

    }

}
