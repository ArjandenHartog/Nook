import SwiftUI
import AVFoundation
import Speech
import EventKit

/// Instellingen: sleutel, meekijken, machtigingen en het koppelen van agents.
struct SettingsView: View {
    @EnvironmentObject private var app: AppModel
    @ObservedObject private var settings = AppSettings.shared

    @State private var keyDraft = ""
    @State private var status = ""
    @State private var refreshTick = 0

    var body: some View {
        Form {
            brainSection
            watchSection
            permissionsSection
            agentsSection
            if !status.isEmpty {
                Section { Text(status).font(.callout).foregroundStyle(.secondary) }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 640)
        .onAppear { refreshTick += 1 }
    }

    // MARK: Brein

    private var brainSection: some View {
        Section("Brein") {
            HStack {
                SecureField("Anthropic API-sleutel", text: $keyDraft)
                Button("Bewaar") {
                    settings.saveAPIKey(keyDraft)
                    keyDraft = ""
                    status = settings.hasAPIKey ? "Sleutel bewaard in de Keychain." : "Sleutel verwijderd."
                }
                .disabled(keyDraft.isEmpty && !settings.hasAPIKey)
            }
            Text(settings.hasAPIKey ? "Er is een sleutel opgeslagen. Laat het veld leeg en druk op Bewaar om hem te wissen." : "Zonder sleutel kan Nook niet nadenken. De sleutel blijft in je Keychain.")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("Model", text: $settings.model)
            Text("Wat je aan Nook vraagt, plus een korte samenvatting van je agenda en open punten, gaat naar de Claude API.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Meekijken

    private var watchSection: some View {
        Section("Meekijken") {
            Toggle("Af en toe zelf meekijken met het scherm", isOn: $settings.autoWatch)
            Text("Standaard uit. Aan: Nook leest elke anderhalve minuut de tekst van het voorste venster (op je Mac, niet het beeld) en stuurt alleen die tekst naar het brein om te zien of er iets te doen is. Wachtwoordmanagers en Nook zelf worden overgeslagen. Handmatig meekijken kan altijd met ⌥⌘N.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Machtigingen

    private var permissionsSection: some View {
        Section("Machtigingen") {
            permissionRow("Agenda", granted: app.calendar.hasEventAccess) {
                Task { await app.calendar.requestEvents(); refreshTick += 1 }
            }
            permissionRow("Herinneringen", granted: app.calendar.hasReminderAccess) {
                Task { await app.calendar.requestReminders(); refreshTick += 1 }
            }
            permissionRow("Microfoon en spraak", granted: VoiceService.permissionsGranted) {
                Task { _ = await app.voice.requestPermissions(); refreshTick += 1 }
            }
            permissionRow("Scherm lezen", granted: CGPreflightScreenCaptureAccess()) {
                CGRequestScreenCaptureAccess()
                refreshTick += 1
            }
            Text("Spotify en Muziek vraagt macOS zelf om toestemming zodra er muziek speelt. Na elke nieuwe build met een ad-hoc handtekening kan macOS de machtigingen opnieuw vragen.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .id(refreshTick)
    }

    private func permissionRow(_ title: String, granted: Bool, request: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(granted ? Color.green : Color.secondary)
            Text(title)
            Spacer()
            if !granted {
                Button("Toestaan", action: request)
            }
        }
    }

    // MARK: Agents

    private var agentsSection: some View {
        Section("Agents") {
            Button("Installeer hook-script") {
                do {
                    let url = try HookScript.install()
                    status = "Script staat in \(url.path)"
                } catch {
                    status = "Installeren mislukte: \(error.localizedDescription)"
                }
            }
            Button("Kopieer Claude Code-configuratie") {
                _ = try? HookScript.install()
                HookScript.copyToPasteboard(HookScript.claudeCodeConfig())
                status = "Gekopieerd. Voeg het samen met het \"hooks\"-deel van ~/.claude/settings.json."
            }
            Button("Kopieer Codex-configuratie") {
                _ = try? HookScript.install()
                HookScript.copyToPasteboard(HookScript.codexConfig())
                status = "Gekopieerd. Zet de regel in ~/.codex/config.toml."
            }
            Text("Nook past de instellingen van je agents nooit zelf aan. Bash-commando's die niet duidelijk onschuldig zijn, komen als vraag in de notch; de rest loopt zoals je agent het zelf al deed. Als Nook niet draait, doen de hooks niets.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
