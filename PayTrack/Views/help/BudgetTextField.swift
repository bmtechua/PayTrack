//
//  BudgetTextField.swift
//  PayTrack
//
//  Created by bmtech on 26.08.2026.
//

import SwiftUI
import UIKit

struct BudgetTextField: UIViewRepresentable {

    @Binding var value: Double

    let onEditingBegan: () -> Void
    let onDone: () -> Void
    
    private func localizedDone() -> String {
        let language =
            UserDefaults.standard.string(forKey: "language") ?? "uk"

        guard
            let path = Bundle.main.path(
                forResource: language,
                ofType: "lproj"
            ),
            let bundle = Bundle(path: path)
        else {
            return NSLocalizedString(
                "done",
                comment: ""
            )
        }

        return NSLocalizedString(
            "done",
            bundle: bundle,
            comment: ""
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(
        context: Context
    ) -> UITextField {

        let textField = UITextField()

        textField.keyboardType = .decimalPad
        textField.delegate = context.coordinator
        textField.text = context.coordinator.formattedValue()

        textField.borderStyle = .none

        // MARK: - Done button

        let doneButton = UIButton(type: .system)

        doneButton.setTitle(
            localizedDone(),
            for: .normal
        )

        doneButton.addTarget(
            context.coordinator,
            action: #selector(
                Coordinator.doneTapped
            ),
            for: .touchUpInside
        )

        doneButton.sizeToFit()

        textField.rightView = doneButton
        textField.rightViewMode = .whileEditing

        context.coordinator.textField = textField

        return textField
    }

    func updateUIView(
        _ textField: UITextField,
        context: Context
    ) {

        context.coordinator.parent = self

        if !textField.isFirstResponder {
            textField.text =
                context.coordinator.formattedValue()
        }

        if let button = textField.rightView as? UIButton {
            button.setTitle(
                localizedDone(),
                for: .normal
            )
            button.sizeToFit()
        }
    }
    

    // MARK: - Coordinator

    final class Coordinator:
        NSObject,
        UITextFieldDelegate {

        var parent: BudgetTextField

        weak var textField: UITextField?

        init(_ parent: BudgetTextField) {
            self.parent = parent
        }

        func formattedValue() -> String {

            let formatter = NumberFormatter()

            formatter.numberStyle = .decimal
            formatter.locale = Locale.current
            formatter.maximumFractionDigits = 2

            return formatter.string(
                from: NSNumber(
                    value: parent.value
                )
            ) ?? ""
        }

        func textFieldDidBeginEditing(
            _ textField: UITextField
        ) {
            parent.onEditingBegan()
        }

        @objc
        func doneTapped() {

            updateValue()

            textField?.resignFirstResponder()

            parent.onDone()
        }

        func textFieldDidEndEditing(
            _ textField: UITextField
        ) {
            updateValue()
        }

        private func updateValue() {

            guard
                let text = textField?.text
            else {
                return
            }

            let formatter = NumberFormatter()

            formatter.numberStyle = .decimal
            formatter.locale = Locale.current

            if let number = formatter.number(
                from: text
            ) {
                parent.value =
                    number.doubleValue
            }
        }
    }
}
