import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = DiagnosticsViewModel()

    var body: some View {
        VStack(spacing: 16) {
            header
            controls

            if viewModel.isRunning {
                ProgressView(viewModel.progressText)
                    .font(.headline)
                    .padding(.vertical, 8)
            } else if !viewModel.progressText.isEmpty {
                Text(viewModel.progressText)
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.results) { result in
                        ResultCard(result: result) {
                            viewModel.performAction(for: result)
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            if !viewModel.reportText.isEmpty {
                reportActions
            }
        }
        .padding(24)
        .frame(minWidth: 780, minHeight: 720)
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("Simple Network Check")
                .font(.system(size: 36, weight: .bold, design: .rounded))

            Text(overviewText)
                .font(.title3)
                .foregroundStyle(overviewColor)

            if let date = viewModel.lastRunDate {
                Text("Last run: \(date.formatted(date: .abbreviated, time: .shortened))")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(overviewColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.runChecks()
            } label: {
                Text(viewModel.isRunning ? "Running..." : "Run Check")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isRunning)
        }
    }

    private var reportActions: some View {
        HStack(spacing: 12) {
            ShareLink(item: viewModel.reportText + "\n\nJSON:\n" + viewModel.reportJSON) {
                Label("Share Report", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)

            Button("Copy Report") {
                viewModel.copyReportToClipboard()
            }
            .buttonStyle(.bordered)

            Spacer()
        }
    }

    private var overviewText: String {
        switch viewModel.overallStatus {
        case .pass: return "Everything looks good"
        case .warn: return "Some checks need attention"
        case .fail: return "Needs attention"
        case .unknown: return "Run checks to see status"
        }
    }

    private var overviewColor: Color {
        switch viewModel.overallStatus {
        case .pass: return .green
        case .warn: return .yellow
        case .fail: return .red
        case .unknown: return .gray
        }
    }
}

private struct ResultCard: View {
    let result: CheckResult
    let onAction: () -> Void
    @State private var showDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: statusSymbol)
                    .foregroundStyle(statusColor)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.title)
                        .font(.headline)
                    Text(result.headline)
                        .font(.title3.weight(.semibold))
                }

                Spacer()
            }

            Text(result.explanation)
                .font(.body)

            HStack(spacing: 10) {
                if result.recommendedAction.kind != .none {
                    Button(result.recommendedAction.label, action: onAction)
                        .buttonStyle(.bordered)
                } else {
                    Text("No action needed")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(showDetails ? "Hide Details" : "Show Details") {
                    showDetails.toggle()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            if showDetails {
                Text(
                    result.technicalDetails.isEmpty
                        ? "No technical details." : result.technicalDetails
                )
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .textSelection(.enabled)
                .padding(10)
                .background(Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(16)
        .background(statusColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(statusColor.opacity(0.45), lineWidth: 1)
        )
    }

    private var statusColor: Color {
        switch result.status {
        case .pass: return .green
        case .warn: return .yellow
        case .fail: return .red
        case .unknown: return .gray
        }
    }

    private var statusSymbol: String {
        switch result.status {
        case .pass: return "checkmark.circle.fill"
        case .warn: return "exclamationmark.triangle.fill"
        case .fail: return "xmark.octagon.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }
}
