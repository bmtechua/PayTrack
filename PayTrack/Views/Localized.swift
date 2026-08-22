//
//  Localized.swift
//  PayTrack
//
//  Created by bmtech on 22.08.2026.
//

import Foundation

func localizedCategory(
    _ key: String?,
    language: String
) -> String {

    guard let key, !key.isEmpty else {
        return localizedString(
            "no_category",
            language: language
        )
    }

    return localizedString(
        key,
        language: language
    )
}


private func localizedString(
    _ key: String,
    language: String
) -> String {

    guard
        let path = Bundle.main.path(
            forResource: language,
            ofType: "lproj"
        ),
        let bundle = Bundle(path: path)
    else {
        return key
    }

    return bundle.localizedString(
        forKey: key,
        value: key,
        table: "Localizable"
    )
}
