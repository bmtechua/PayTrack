//
//  PushDeviceService.swift.swift
//  PayTrack
//
//  Created by bmtech on 09.09.2026.
//

import Foundation
import UIKit
import Supabase

@MainActor
final class PushDeviceService {

    static let shared = PushDeviceService()

    private let client = SupabaseManager.shared.client

    private init() {}

    // MARK: - Device ID

    private var deviceID: String {

        if let existing =
            UserDefaults.standard.string(
                forKey: "pushDeviceID"
            ) {

            return existing
        }

        let newID = UUID().uuidString

        UserDefaults.standard.set(
            newID,
            forKey: "pushDeviceID"
        )

        return newID
    }

    // MARK: - Register device

    func registerDevice() async {

        do {

            let user =
                try await client.auth.session.user

            struct PushDevice: Encodable {

                let user_id: UUID
                let device_id: String
                let push_token: String?
                let platform: String
                let device_name: String?
            }

            let device = PushDevice(
                user_id: user.id,
                device_id: deviceID,
                push_token: nil,
                platform: platform,
                device_name: UIDevice.current.name
            )

            try await client
                .from("push_devices")
                .upsert(
                    device,
                    onConflict: "user_id,device_id"
                )
                .execute()

            AppLogger.shared.info(
                "Push device registered: \(deviceID)"
            )

        } catch {

            AppLogger.shared.error(
                "Push device registration failed: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Platform

    private var platform: String {

        switch UIDevice.current.userInterfaceIdiom {

        case .pad:
            return "iPadOS"

        case .phone:
            return "iOS"

        default:
            return "unknown"
        }
    }
}
