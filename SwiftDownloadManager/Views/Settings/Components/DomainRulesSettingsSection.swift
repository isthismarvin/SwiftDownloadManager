import SwiftUI

private extension DomainPolicy {
    var settingsIcon: String {
        switch self {
        case .default: return "gearshape"
        case .autoStart: return "bolt.fill"
        case .alwaysAsk: return "hand.raised.fill"
        case .blocked: return "nosign"
        }
    }

    var settingsColor: Color {
        switch self {
        case .default: return .secondary
        case .autoStart: return .green
        case .alwaysAsk: return .blue
        case .blocked: return .red
        }
    }

    @MainActor
    func settingsHelp() -> String {
        switch self {
        case .default:
            return L10n.t(
                de: "Normales Verhalten — Bestätigungs-Dialog gemäß App-Einstellung.",
                en: "Normal behavior — confirmation dialog according to app settings."
            )
        case .autoStart:
            return L10n.t(
                de: "Downloads von dieser Domain starten ohne Bestätigungs-Dialog.",
                en: "Downloads from this domain start without a confirmation dialog."
            )
        case .alwaysAsk:
            return L10n.t(
                de: "Zeigt immer den Bestätigungs-Dialog, auch wenn er global deaktiviert ist.",
                en: "Always shows the confirmation dialog, even when globally disabled."
            )
        case .blocked:
            return L10n.t(
                de: "Downloads von dieser Domain werden abgelehnt.",
                en: "Downloads from this domain are rejected."
            )
        }
    }
}

struct DomainRulesSettingsSection: View {
    @Binding var rules: [DomainRule]
    @State private var newDomainPattern = ""
    @State private var newDomainPolicy: DomainPolicy = .alwaysAsk

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if rules.isEmpty {
                emptyState
            } else {
                VStack(spacing: 6) {
                    ForEach(rules, id: \.pattern) { rule in
                        DomainRuleRow(rule: rule) {
                            DomainRuleStore.removeRule(pattern: rule.pattern)
                            reloadRules()
                        }
                    }
                }
            }

            addRuleCard
        }
        .settingsPanelStack()
    }

    private var emptyState: some View {
        SettingsRoundedCard {
            VStack(spacing: 8) {
                Image(systemName: "globe.badge.chevron.backward")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.tertiary)

                Text(L10n.t(de: "Keine Domain-Regeln", en: "No domain rules"))
                    .font(.subheadline.weight(.medium))

                Text(L10n.t(
                    de: "Lege fest, welche Hosts automatisch starten, bestätigt oder blockiert werden.",
                    en: "Define which hosts auto-start, require confirmation, or are blocked."
                ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private var addRuleCard: some View {
        SettingsRoundedCard {
            VStack(alignment: .leading, spacing: 10) {
                SettingsControlRow(alignment: .firstTextBaseline) {
                    Label(L10n.t(de: "Neue Regel", en: "New rule"), systemImage: "plus.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                } control: {
                    TextField(L10n.t(de: "example.com oder *.cdn.net", en: "example.com or *.cdn.net"), text: $newDomainPattern)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .help(L10n.t(
                            de: "Host oder Wildcard (*.example.com). Längere Muster haben Vorrang.",
                            en: "Host or wildcard (*.example.com). Longer patterns take precedence."
                        ))
                }

                SettingsControlRow(alignment: .center) {
                    Text(L10n.t(de: "Richtlinie", en: "Policy"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                } control: {
                    HStack(spacing: 10) {
                        Menu {
                            ForEach(DomainPolicy.allCases, id: \.self) { policy in
                                Button {
                                    newDomainPolicy = policy
                                } label: {
                                    Label(policy.displayName, systemImage: policy.settingsIcon)
                                }
                            }
                        } label: {
                            DomainPolicyBadge(policy: newDomainPolicy)
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                        .help(newDomainPolicy.settingsHelp())

                        Button(L10n.t(de: "Hinzufügen", en: "Add")) {
                            addRule()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(newDomainPattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .help(L10n.t(de: "Regel für die eingegebene Domain speichern.", en: "Save rule for the entered domain."))
                    }
                }
            }
        }
    }

    private func addRule() {
        let pattern = newDomainPattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pattern.isEmpty else { return }
        DomainRuleStore.addRule(pattern: pattern, policy: newDomainPolicy)
        newDomainPattern = ""
        reloadRules()
    }

    private func reloadRules() {
        rules = DomainRuleStore.allRules()
    }
}

private struct DomainRuleRow: View {
    let rule: DomainRule
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: rule.pattern.hasPrefix("*.") ? "network" : "globe")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(rule.pattern)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 8)

            DomainPolicyBadge(policy: rule.policy)

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderless)
            .opacity(isHovering ? 1 : 0.45)
            .help(L10n.t(de: "Regel entfernen", en: "Remove rule"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .appGlassRow(isHighlighted: isHovering)
        .onHover { isHovering = $0 }
        .frame(maxWidth: .infinity, alignment: .leading)
        .settingsHelp("\(rule.pattern): \(rule.policy.settingsHelp())")
    }
}

private struct DomainPolicyBadge: View {
    let policy: DomainPolicy

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: policy.settingsIcon)
                .font(.system(size: 10, weight: .semibold))
            Text(policy.displayName)
                .lineLimit(1)
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(policy.settingsColor)
        .appGlassChip(tint: policy.settingsColor.opacity(0.35))
        .settingsHelp(policy.settingsHelp())
    }
}
