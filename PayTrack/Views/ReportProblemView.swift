//
//  ReportProblemView.swift
//  PayTrack
//
//  Created by bmtech on 08.09.2026.
//

import SwiftUI

struct ReportProblemView: View {

    @State private var problemDescription = ""

    var body: some View {

        Form {

            Section {
                TextEditor(text: $problemDescription)
                    .frame(minHeight: 180)
            } header: {
                Text("problem_description")
            } footer: {
                Text("problem_description_hint")
            }

            Section {

                Button {
                    // Відправку додамо наступним кроком
                } label: {
                    HStack {
                        Spacer()
                        Text("send_report")
                        Spacer()
                    }
                }
                .disabled(problemDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .navigationTitle("report_problem")
        .navigationBarTitleDisplayMode(.inline)
    }
}
