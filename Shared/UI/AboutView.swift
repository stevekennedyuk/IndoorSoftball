import SwiftUI

/// About screen: the app, its developer and NetTek. Opened from Settings on
/// iPhone, iPad and Apple Watch.
struct AboutView: View {
    var compact = false

    var body: some View {
        ScrollView {
            VStack(spacing: compact ? 10 : 22) {
                header
                developerCard
                netTekCard
                #if os(iOS)
                linksCard
                #endif
                Text("\(AppInfo.copyright). All rights reserved.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, compact ? 0 : 4)
            }
            .padding(compact ? 4 : 20)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("About")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: Sections

    private var header: some View {
        VStack(spacing: compact ? 4 : 10) {
            #if os(iOS)
            Image("AboutIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 112, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
                .shadow(color: .black.opacity(0.4), radius: 10, y: 5)
            #else
            Image(systemName: "stopwatch.fill")
                .font(.system(size: 30))
                .foregroundStyle(Theme.powderBlue)
            #endif
            Text(AppInfo.appName)
                .font(compact ? .headline : .title.weight(.heavy))
                .multilineTextAlignment(.center)
            Text("Version \(AppInfo.version)")
                .font(compact ? .caption2 : .subheadline)
                .foregroundStyle(.secondary)
            if !compact {
                Text(AppInfo.tagline)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var developerCard: some View {
        card {
            VStack(alignment: .leading, spacing: compact ? 2 : 6) {
                label("DEVELOPED BY")
                Text(AppInfo.developer)
                    .font(compact ? .headline : .title3.weight(.bold))
                Text(AppInfo.copyright)
                    .font(compact ? .caption2 : .subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var netTekCard: some View {
        card {
            VStack(alignment: .leading, spacing: compact ? 4 : 8) {
                label("ABOUT NETTEK")
                Text(AppInfo.aboutNetTek)
                    .font(compact ? .caption2 : .body)
                    .fixedSize(horizontal: false, vertical: true)
                if !compact {
                    Text(AppInfo.netTekServices)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    #if os(iOS)
    private var linksCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                Link(destination: AppInfo.website) {
                    Label("nettek.uk", systemImage: "globe")
                }
                Link(destination: AppInfo.supportURL) {
                    Label("Help & support", systemImage: "questionmark.circle")
                }
                Link(destination: AppInfo.privacyURL) {
                    Label("Privacy policy", systemImage: "hand.raised")
                }
                Link(destination: AppInfo.feedbackMailURL) {
                    Label("Email feedback", systemImage: "envelope")
                }
            }
            .font(.body.weight(.medium))
        }
    }
    #endif

    // MARK: Helpers

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.heavy))
            .foregroundStyle(Theme.powderBlue)
    }

    private func card<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(compact ? 8 : 16)
            .background(RoundedRectangle(cornerRadius: compact ? 10 : 16).fill(Theme.card))
    }
}
