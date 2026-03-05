import SwiftUI

struct ToneProfileSetupView: View {
    let onComplete: (ToneProfile) -> Void

    @State private var currentIndex = 0
    @State private var likedIndices: Set<Int> = []
    @State private var dragOffset: CGSize = .zero
    @State private var showResult = false
    @State private var detectedProfile: ToneProfile = .defaultProfile

    private let samples = SampleReply.all

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("Does this sound like you?")
                    .font(.largeTitle.bold())
                Text("Swipe right if yes, left if no.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 32)
            .padding(.horizontal, 24)

            ProgressView(value: Double(currentIndex), total: Double(samples.count))
                .tint(.indigo)
                .padding(.horizontal, 24)
                .padding(.top, 16)

            Spacer()

            if showResult {
                toneResultView
            } else if currentIndex < samples.count {
                swipeCardView
            }

            Spacer()

            if !showResult {
                HStack(spacing: 32) {
                    Button(action: { swipe(liked: false) }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    Button(action: { swipe(liked: true) }) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(.green.opacity(0.8))
                    }
                }
                .padding(.bottom, 48)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showResult)
    }

    // MARK: - Card

    private var swipeCardView: some View {
        let sample = samples[currentIndex]
        return VStack(spacing: 20) {
            Text(sample.scenario)
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Text("\"\(sample.replyText)\"")
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(24)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)
                .offset(dragOffset)
                .rotationEffect(.degrees(Double(dragOffset.width) / 20))
                .overlay(
                    Group {
                        if dragOffset.width > 30 {
                            Text("Sounds like me")
                                .font(.headline.bold())
                                .foregroundStyle(.green)
                                .padding(8)
                                .background(Color.green.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .padding()
                        } else if dragOffset.width < -30 {
                            Text("Not my style")
                                .font(.headline.bold())
                                .foregroundStyle(.red)
                                .padding(8)
                                .background(Color.red.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .padding()
                        }
                    }
                )
                .gesture(
                    DragGesture()
                        .onChanged { dragOffset = $0.translation }
                        .onEnded { value in
                            if value.translation.width > 80 { swipe(liked: true) }
                            else if value.translation.width < -80 { swipe(liked: false) }
                            else { withAnimation(.spring()) { dragOffset = .zero } }
                        }
                )
        }
    }

    // MARK: - Result

    private var toneResultView: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 64))
                .foregroundStyle(.indigo)

            VStack(spacing: 8) {
                Text("Your tone:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(detectedProfile.label)
                    .font(.title.bold())
            }

            VStack(spacing: 12) {
                ForEach(ToneProfile.allPresets) { preset in
                    Button(action: {
                        detectedProfile = preset
                    }) {
                        HStack {
                            Text(preset.label)
                                .font(.headline)
                            Spacer()
                            if detectedProfile.label == preset.label {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.indigo)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(detectedProfile.label == preset.label ? Color.indigo : Color(.separator),
                                        lineWidth: detectedProfile.label == preset.label ? 2 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)

            Button(action: { onComplete(detectedProfile) }) {
                Text("Looks right")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.indigo)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Logic

    private func swipe(liked: Bool) {
        withAnimation(.spring()) { dragOffset = .zero }

        if liked { likedIndices.insert(currentIndex) }

        if currentIndex < samples.count - 1 {
            currentIndex += 1
        } else {
            detectedProfile = ToneDetector.detect(from: samples, likes: likedIndices)
            showResult = true
        }
    }
}
