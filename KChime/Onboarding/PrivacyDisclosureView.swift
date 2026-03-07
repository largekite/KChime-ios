import SwiftUI

struct PrivacyDisclosureView: View {
    let onAccept: () -> Void

    private let items: [(icon: String, title: String, body: String)] = [
        (
            "eye.slash.fill",
            "KChime only sees what you share",
            "Unlike a default keyboard, KChime cannot read what you type in other apps. It only processes text you explicitly paste into its input field."
        ),
        (
            "server.rack",
            "Messages are never stored",
            "Message content is sent to generate a reply and immediately discarded. Nothing you type is saved on our servers — ever, by default."
        ),
        (
            "network",
            "Why Full Access is required",
            "iOS requires \"Full Access\" for any keyboard that makes network calls. KChime needs it only to reach the AI. We cannot receive your other keystrokes."
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your privacy matters")
                            .font(.largeTitle.bold())
                        Text("Read this before enabling Full Access.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 24)

                    ForEach(items, id: \.title) { item in
                        HStack(alignment: .top, spacing: 16) {
                            Image(systemName: item.icon)
                                .font(.title2)
                                .foregroundStyle(.teal)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.headline)
                                Text(item.body)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    Text("You can delete all your data at any time from Settings.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 16)
                }
                .padding(.horizontal, 24)
            }

            Button(action: onAccept) {
                Text("I understand, continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.teal)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
            .background(
                LinearGradient(
                    colors: [Color(.systemBackground).opacity(0), Color(.systemBackground)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
            )
        }
        .background(Color(.systemBackground))
    }
}
