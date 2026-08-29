//
//  SyncService+Realtime.swift
//  PayTrack
//
//  Created by bmtech on 29.08.2026.
//

import Foundation
import CoreData
import Supabase

extension SyncService {
    // MARK: - Realtime categories

    func startCategoriesRealtime() async {

        guard categoriesChannel == nil else {
            return
        }

        do {

            let user = try await client.auth.session.user

            AppLogger.shared.info(
                "Realtime user ID: \(user.id.uuidString)"
            )

            let channel = client.channel(
                "categories-realtime-\(user.id.uuidString)"
            )

            let changes = channel.postgresChange(
                AnyAction.self,
                schema: "public",
                table: "categories"
            )

            categoriesChannel = channel

            Task { @MainActor in

                for await change in changes {

                    switch change {

                    case .insert(let action):

                        self.applyRealtimeCategoryInsert(
                            action.record
                        )

                        AppLogger.shared.info(
                            "Realtime category INSERT received"
                        )

                    case .update(let action):

                        self.applyRealtimeCategoryUpdate(
                            action.record
                        )

                        AppLogger.shared.info(
                            "Realtime category UPDATE received"
                        )

                    case .delete(let action):

                        self.applyRealtimeCategoryDelete(
                            action.oldRecord
                        )

                        AppLogger.shared.info(
                            "Realtime category DELETE received"
                        )
                    }
                }
            }

            try await channel.subscribeWithError()

            AppLogger.shared.info(
                "Categories Realtime subscribed"
            )

        } catch {

            AppLogger.shared.error(
                "Categories Realtime failed: \(error.localizedDescription)"
            )
        }
    }
    
    // MARK: - Stop Realtime categories

    func stopCategoriesRealtime() async {

        guard let channel = categoriesChannel else {
            return
        }

        await client.removeChannel(channel)

        categoriesChannel = nil

        AppLogger.shared.info(
            "Categories Realtime unsubscribed"
        )
    }
    
    // MARK: - Realtime expenses

    func startExpensesRealtime() async {

        guard expensesChannel == nil else {
            return
        }

        do {

            let user = try await client.auth.session.user

            let channel = client.channel(
                "expenses-realtime-\(user.id.uuidString)"
            )

            let changes = channel.postgresChange(
                AnyAction.self,
                schema: "public",
                table: "expenses"
            )

            expensesChannel = channel

            Task { @MainActor in

                for await change in changes {

                    switch change {

                    case .insert(let action):

                        self.applyRealtimeExpenseInsert(
                            action.record
                        )

                        AppLogger.shared.info(
                            "Realtime expense INSERT received"
                        )

                    case .update(let action):

                        self.applyRealtimeExpenseUpdate(
                            action.record
                        )

                        AppLogger.shared.info(
                            "Realtime expense UPDATE received"
                        )

                    case .delete(let action):

                        self.applyRealtimeExpenseDelete(
                            action.oldRecord
                        )

                        AppLogger.shared.info(
                            "Realtime expense DELETE received"
                        )
                    }
                }
            }

            try await channel.subscribeWithError()

            AppLogger.shared.info(
                "Expenses Realtime subscribed"
            )

        } catch {

            AppLogger.shared.error(
                "Expenses Realtime failed: \(error.localizedDescription)"
            )
        }
    }
}
