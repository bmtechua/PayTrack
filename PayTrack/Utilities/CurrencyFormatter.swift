//
//  CurrencyFormatter.swift
//  PayTrack
//
//  Created by bmtech on 22.08.2026.
//

import Foundation

func formatAmount(_ amount: Double, currency: String) -> String {

    switch currency {
    case "EUR":
        return String(format: "%.2f €", amount)

    case "USD":
        return String(format: "%.2f $", amount)

    default:
        return String(format: "%.2f ₴", amount)
    }
}


