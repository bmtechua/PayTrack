//
//  SyncService+Profile.swift
//  PayTrack
//
//  Created by bmtech on 04.09.2026.
//

import Foundation
import Supabase

extension SyncService {

    // MARK: - Sync profile settings to Supabase

    func syncProfileSettings() async {

        do {
            let user = try await client.auth.session.user

            let currency =
                UserDefaults.standard.string(forKey: "currency") ?? "UAH"

            let monthlyBudget =
                UserDefaults.standard.double(forKey: "monthlyBudget")

            let budget = monthlyBudget == 0 ? 5000 : monthlyBudget

            struct ProfileSettings: Encodable {
                let id: UUID
                let currency: String
                let monthly_budget: Double
            }

            let profile = ProfileSettings(
                id: user.id,
                currency: currency,
                monthly_budget: budget
            )

            try await client
                .from("profiles")
                .upsert(profile)
                .execute()

            AppLogger.shared.info(
                "Profile settings synced: currency=\(currency), budget=\(budget)"
            )

        } catch {
            AppLogger.shared.error(
                "Profile settings sync failed: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Load profile settings from Supabase

    func loadProfileSettings() async {

        do {
            let user = try await client.auth.session.user

            struct ProfileSettings: Decodable {
                let currency: String
                let monthly_budget: Double
            }

            let profile: ProfileSettings = try await client
                .from("profiles")
                .select("currency, monthly_budget")
                .eq("id", value: user.id.uuidString)
                .single()
                .execute()
                .value

            UserDefaults.standard.set(
                profile.currency,
                forKey: "currency"
            )

            UserDefaults.standard.set(
                profile.monthly_budget,
                forKey: "monthlyBudget"
            )

            AppLogger.shared.info(
                "Profile settings loaded: currency=\(profile.currency), budget=\(profile.monthly_budget)"
            )

        } catch {
            AppLogger.shared.error(
                "Profile settings load failed: \(error.localizedDescription)"
            )
        }
    }
}
