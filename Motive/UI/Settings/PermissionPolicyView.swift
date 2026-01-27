//
//  PermissionPolicyView.swift
//  Motive
//
//  Settings view for configuring file operation policies.
//

import SwiftUI

struct PermissionPolicyView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var operationPolicies: [FileOperation: PermissionPolicy] = [:]
    
    private var isDark: Bool { colorScheme == .dark }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // File Operations Card
            SettingsCard(title: L10n.Settings.fileOperations, icon: "doc.badge.gearshape") {
                VStack(spacing: 0) {
                    ForEach(Array(FileOperation.allCases.enumerated()), id: \.element) { index, operation in
                        SettingsRow(
                            label: operation.localizedName,
                            description: operation.localizedDescription,
                            showDivider: index < FileOperation.allCases.count - 1
                        ) {
                            HStack(spacing: 8) {
                                // Risk indicator
                                Circle()
                                    .fill(riskColor(for: operation.riskLevel))
                                    .frame(width: 8, height: 8)
                                
                                // Policy picker
                                Picker("", selection: Binding(
                                    get: { operationPolicies[operation] ?? .alwaysAsk },
                                    set: { newPolicy in
                                        operationPolicies[operation] = newPolicy
                                        FileOperationPolicy.shared.setDefaultPolicy(newPolicy, for: operation)
                                    }
                                )) {
                                    ForEach(PermissionPolicy.allCases, id: \.self) { policy in
                                        Text(policy.localizedName).tag(policy)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 120)
                            }
                        }
                    }
                }
            }
            
            // Legend Card
            SettingsCard(title: L10n.Settings.riskLevels, icon: "shield.lefthalf.filled") {
                VStack(spacing: 0) {
                    SettingsRow(label: L10n.Settings.riskLow, description: L10n.Settings.riskLowDesc, showDivider: true) {
                        Circle().fill(Color.green).frame(width: 10, height: 10)
                    }
                    SettingsRow(label: L10n.Settings.riskMedium, description: L10n.Settings.riskMediumDesc, showDivider: true) {
                        Circle().fill(Color.yellow).frame(width: 10, height: 10)
                    }
                    SettingsRow(label: L10n.Settings.riskHigh, description: L10n.Settings.riskHighDesc, showDivider: true) {
                        Circle().fill(Color.orange).frame(width: 10, height: 10)
                    }
                    SettingsRow(label: L10n.Settings.riskCritical, description: L10n.Settings.riskCriticalDesc, showDivider: false) {
                        Circle().fill(Color.red).frame(width: 10, height: 10)
                    }
                }
            }
            
            // Reset Button
            HStack {
                Spacer()
                Button(action: {
                    FileOperationPolicy.shared.resetToDefaults()
                    loadCurrentPolicies()
                }) {
                    Text(L10n.Settings.resetToDefaults)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.Aurora.textMuted)
            }
        }
        .onAppear {
            loadCurrentPolicies()
        }
    }
    
    private func loadCurrentPolicies() {
        for operation in FileOperation.allCases {
            let policy = FileOperationPolicy.shared.policy(for: operation, path: "")
            operationPolicies[operation] = policy
        }
    }
    
    private func riskColor(for level: RiskLevel) -> Color {
        switch level {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - PermissionPolicy Extensions

extension PermissionPolicy: CaseIterable {
    static var allCases: [PermissionPolicy] {
        [.alwaysAllow, .alwaysAsk, .askOnce, .alwaysDeny]
    }
}

#Preview {
    PermissionPolicyView()
        .frame(width: 480, height: 600)
        .padding()
}
