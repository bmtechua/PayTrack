//
//  BankTransactionService.swift
//  PayTrack
//
//  Created by bmtech on 26.08.2026.
//

import CoreData

final class BankTransactionService {

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func transactionExists(
        transactionID: String
    ) -> Bool {

        let request: NSFetchRequest<Expense> =
            Expense.fetchRequest()

        request.fetchLimit = 1

        request.predicate = NSPredicate(
            format: "transactionID == %@",
            transactionID
        )

        do {
            return try context.count(
                for: request
            ) > 0
        } catch {
            AppLogger.shared.error(
                "Transaction check failed: \(error.localizedDescription)"
            )

            return false
        }
    }

    func importTransaction(
        transactionID: String,
        merchantName: String,
        amount: Double,
        date: Date,
        category: Category? = nil
    ) {

        guard !transactionExists(
            transactionID: transactionID
        ) else {

            AppLogger.shared.info(
                "Transaction skipped - already imported: \(transactionID)"
            )

            return
        }

        let expense = Expense(context: context)

        expense.id = UUID()
        expense.transactionID = transactionID
        expense.merchantName = merchantName
        expense.title = merchantName
        expense.amount = amount
        expense.date = date
        expense.category = category
        expense.source = ExpenseSource.bank.rawValue

        do {

            try context.save()

            AppLogger.shared.info(
                "Bank transaction imported: \(merchantName), amount: \(amount)"
            )

        } catch {

            context.delete(expense)

            AppLogger.shared.error(
                "Failed to import bank transaction: \(error.localizedDescription)"
            )
        }
    }
}
