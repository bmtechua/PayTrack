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

            let user =
                try await client.auth.session.user

            AppLogger.shared.info(
                "Realtime user ID: \(user.id.uuidString)",
                category: .realtime
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
                            "Realtime category INSERT received",
                            category: .realtime
                        )

                    case .update(let action):

                        self.applyRealtimeCategoryUpdate(
                            action.record
                        )

                        AppLogger.shared.info(
                            "Realtime category UPDATE received",
                            category: .realtime
                        )

                    case .delete(let action):

                        self.applyRealtimeCategoryDelete(
                            action.oldRecord
                        )

                        AppLogger.shared.info(
                            "Realtime category DELETE received",
                            category: .realtime
                        )
                    }
                }
            }

            try await channel.subscribeWithError()

            AppLogger.shared.info(
                "Categories Realtime subscribed",
                category: .realtime
            )

        } catch {

            AppLogger.shared.error(
                "Categories Realtime failed: \(error.localizedDescription)",
                category: .realtime
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
            "Categories Realtime unsubscribed",
            category: .realtime
        )
    }

    // MARK: - Realtime expenses

    func startExpensesRealtime() async {

        guard expensesChannel == nil else {
            return
        }

        do {

            let user =
                try await client.auth.session.user

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
                            "Realtime expense INSERT received",
                            category: .realtime
                        )

                    case .update(let action):

                        self.applyRealtimeExpenseUpdate(
                            action.record
                        )

                        AppLogger.shared.info(
                            "Realtime expense UPDATE received",
                            category: .realtime
                        )

                    case .delete(let action):

                        self.applyRealtimeExpenseDelete(
                            action.oldRecord
                        )

                        AppLogger.shared.info(
                            "Realtime expense DELETE received",
                            category: .realtime
                        )
                    }
                }
            }

            try await channel.subscribeWithError()

            AppLogger.shared.info(
                "Expenses Realtime subscribed",
                category: .realtime
            )

        } catch {

            AppLogger.shared.error(
                "Expenses Realtime failed: \(error.localizedDescription)",
                category: .realtime
            )
        }
    }

    // MARK: - Stop Realtime expenses

    func stopExpensesRealtime() async {

        guard let channel = expensesChannel else {
            return
        }

        await client.removeChannel(channel)

        expensesChannel = nil

        AppLogger.shared.info(
            "Expenses Realtime unsubscribed",
            category: .realtime
        )
    }

    // MARK: - Realtime profile

    func startProfileRealtime() async {

        guard profileChannel == nil else {
            return
        }

        do {

            let user =
                try await client.auth.session.user

            let channel = client.channel(
                "profile-realtime-\(user.id.uuidString)"
            )

            let changes = channel.postgresChange(
                AnyAction.self,
                schema: "public",
                table: "profiles"
            )

            profileChannel = channel

            Task { @MainActor in

                for await change in changes {

                    switch change {

                    case .insert(let action):

                        await self.applyRealtimeProfileUpdate(
                            action.record
                        )

                        AppLogger.shared.info(
                            "Realtime profile INSERT received",
                            category: .realtime
                        )

                    case .update(let action):

                        await self.applyRealtimeProfileUpdate(
                            action.record
                        )

                        AppLogger.shared.info(
                            "Realtime profile UPDATE received",
                            category: .realtime
                        )

                    case .delete:

                        AppLogger.shared.warning(
                            "Realtime profile DELETE received",
                            category: .realtime
                        )
                    }
                }
            }

            try await channel.subscribeWithError()

            AppLogger.shared.info(
                "Profile Realtime subscribed",
                category: .realtime
            )

        } catch {

            AppLogger.shared.error(
                "Profile Realtime failed: \(error.localizedDescription)",
                category: .realtime
            )
        }
    }

    // MARK: - Stop Realtime profile

    func stopProfileRealtime() async {

        guard let channel = profileChannel else {
            return
        }

        await client.removeChannel(channel)

        profileChannel = nil

        AppLogger.shared.info(
            "Profile Realtime unsubscribed",
            category: .realtime
        )
    }

    // MARK: - Apply realtime profile

    func applyRealtimeProfileUpdate(
        _ record: [String: AnyJSON]
    ) async {

        do {

            let data = try JSONEncoder().encode(record)

            struct ProfileSettings: Decodable {
                let id: UUID
                let currency: String
                let monthly_budget: Double
                let language: String
            }

            let profile =
                try JSONDecoder().decode(
                    ProfileSettings.self,
                    from: data
                )

            let currentUser =
                try await client.auth.session.user

            guard profile.id == currentUser.id else {
                return
            }

            UserDefaults.standard.set(
                profile.currency,
                forKey: "currency"
            )

            UserDefaults.standard.set(
                profile.monthly_budget,
                forKey: "monthlyBudget"
            )

            UserDefaults.standard.set(
                profile.language,
                forKey: "language"
            )

            AppLogger.shared.info(
                "Realtime profile applied: currency=\(profile.currency), budget=\(profile.monthly_budget), language=\(profile.language)",
                category: .realtime
            )

        } catch {

            AppLogger.shared.error(
                "Realtime profile update failed: \(error.localizedDescription)",
                category: .realtime
            )
        }
    }
}
