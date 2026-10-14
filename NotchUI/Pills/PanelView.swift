import SwiftUI

/// Het uitgeklapte paneel met vier tabs. De tabbalk staat altijd bovenaan.
struct PanelView: View {
    @ObservedObject var viewModel: NotchViewModel
    let tab: PanelTab

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            content
                .padding(.top, 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            HStack(spacing: 22) {
                ForEach(PanelTab.allCases) { t in
                    Button {
                        viewModel.show(.panel(t))
                    } label: {
                        Text(t.title)
                            .font(NookTheme.font(13.5, .medium))
                            .foregroundStyle(t == tab ? NookTheme.paper : NookTheme.textTertiary)
                            .padding(.vertical, 6)
                            .overlay(alignment: .bottom) {
                                Rectangle()
                                    .fill(t == tab ? NookTheme.paper : Color.clear)
                                    .frame(height: 1.5)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
            HStack(spacing: 2) {
                NookIconButton(systemName: "mic", label: "Praat met Nook") { viewModel.startListening() }
                NookIconButton(systemName: "xmark", label: "Sluiten") { viewModel.show(.idle) }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .today: TodayTab(viewModel: viewModel)
        case .agents: AgentsTab(viewModel: viewModel)
        case .music: MusicTab()
        case .shelf: ShelfTab()
        }
    }
}
