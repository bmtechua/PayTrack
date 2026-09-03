import Foundation
import CoreData
import Supabase

extension SyncService {

    // MARK: - Prepare local data for user

    func prepareForUser(_ userID: UUID) async {

        let key = "activeUserID"
        let currentUserID = UserDefaults.standard.string(forKey: key)

        // Already active user
        if currentUserID == userID.uuidString {
            return
        }

        AppLogger.shared.info(
            "Preparing local data for user: \(userID)"
        )

        // We do NOT delete local data here.
        //
        // Free data:
        // userID == nil
        //
        // Premium data:
        // userID == current Premium user's UUID
        //
        // This allows us to switch between Free and Premium
        // without losing local data.

        UserDefaults.standard.set(
            userID.uuidString,
            forKey: key
        )

        AppLogger.shared.info(
            "Active Premium user changed to: \(userID)"
        )
    }

    // MARK: - Clear Premium session

    func clearLocalData() async {

        // IMPORTANT:
        // We do NOT delete Core Data here.
        //
        // Premium user's local data must remain on the device
        // so it can be restored when the user logs in again.
        //
        // We only remove the active user marker.

        UserDefaults.standard.removeObject(
            forKey: "activeUserID"
        )

        AppLogger.shared.info(
            "Premium session cleared. Local data preserved."
        )
    }
}
