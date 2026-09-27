import SwiftUI

struct SiteLoginsSettingsSection: View {
    @State private var credentials: [SiteCredential] = []
    @State private var isShowingAddSheet = false

    @State private var newHost = ""
    @State private var newUsername = ""
    @State private var newSecret = ""
    @State private var newAuthType = AuthType.basic

    var body: some View {
        SettingsRoundedCard {
            VStack(alignment: .leading, spacing: 8) {
                if credentials.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "key.fill")
                            .foregroundStyle(.secondary)
                        Text(L10n.t(
                            de: "Keine Website-Zugangsdaten hinterlegt. " +
                                "Authentifizierungsdaten für geschützte Server werden hier gespeichert.",
                            en: "No site credentials stored. " +
                                "Authentication credentials for protected servers will appear here."
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } else {
                    ForEach(credentials) { cred in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(cred.host)
                                        .font(.subheadline.weight(.medium))
                                    Text(cred.authType.displayName)
                                        .font(.caption2)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(Capsule().fill(.quaternary))
                                }
                                if !cred.username.isEmpty {
                                    Text(cred.username)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button {
                                deleteCredential(cred)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.borderless)
                            .help(L10n.t(de: "Zugangsdaten entfernen", en: "Remove credentials"))
                        }
                        if cred != credentials.last {
                            Divider()
                        }
                    }
                }

                Divider()

                HStack {
                    Spacer()
                    Button {
                        resetSheetFields()
                        isShowingAddSheet = true
                    } label: {
                        Label(
                            L10n.t(de: "Login hinzufügen…", en: "Add Site Login…"),
                            systemImage: "plus.circle"
                        )
                    }
                    .controlSize(.small)
                }
            }
        }
        .onAppear {
            reload()
        }
        .sheet(isPresented: $isShowingAddSheet) {
            addSheetView
        }
    }

    private var addSheetView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.t(de: "Website-Zugangsdaten hinzufügen", en: "Add Site Login"))
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.t(de: "Host / Domain", en: "Host / Domain"))
                        .font(.caption.weight(.medium))
                    TextField("example.com oder *.example.com", text: $newHost)
                        .textFieldStyle(.roundedBorder)
                }

                Picker(L10n.t(de: "Authentifizierungstyp", en: "Authentication Type"), selection: $newAuthType) {
                    ForEach(AuthType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                if newAuthType == .basic {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.t(de: "Benutzername", en: "Username"))
                            .font(.caption.weight(.medium))
                        TextField("user", text: $newUsername)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.t(de: "Passwort", en: "Password"))
                            .font(.caption.weight(.medium))
                        SecureField("••••••••", text: $newSecret)
                            .textFieldStyle(.roundedBorder)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.t(de: "Bearer Token", en: "Bearer Token"))
                            .font(.caption.weight(.medium))
                        SecureField("eyJh...", text: $newSecret)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }

            HStack {
                Button(L10n.t(de: "Abbrechen", en: "Cancel")) {
                    isShowingAddSheet = false
                }
                Spacer()
                Button(L10n.t(de: "Speichern", en: "Save")) {
                    saveNewCredential()
                }
                .buttonStyle(.borderedProminent)
                .disabled(newHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 400)
    }

    private func reload() {
        credentials = SiteCredentialStore.allCredentials()
    }

    private func resetSheetFields() {
        newHost = ""
        newUsername = ""
        newSecret = ""
        newAuthType = .basic
    }

    private func saveNewCredential() {
        let cred = SiteCredential(
            host: newHost,
            username: newUsername,
            secret: newSecret,
            authType: newAuthType
        )
        SiteCredentialStore.save(cred)
        reload()
        isShowingAddSheet = false
    }

    private func deleteCredential(_ cred: SiteCredential) {
        SiteCredentialStore.remove(host: cred.host)
        reload()
    }
}
