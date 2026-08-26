//
//  SupabaseManager.swift
//  PayTrack
//
//  Created by bmtech on 26.08.2026.
//

import Foundation
import Supabase

final class SupabaseManager {

    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "https://caqfffuldsjazyfqhlkd.supabase.co")!,
            supabaseKey: "sb_publishable_VpK5ej0YwoxAe2Ew05RcaQ_6Wn5BDbC"
        )
    }
}
