import SwiftUI

struct CrossPromoView: View {
    let app: PromoApp
    let title: String
    let onInstall: () -> Void
    let onDismissToday: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            // Card
            VStack(spacing: 0) {
                // Title
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 24)

                Spacer().frame(height: 20)

                // App Icon
                AsyncImage(url: URL(string: app.iconUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.gray.opacity(0.2))
                }
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 20))

                Spacer().frame(height: 16)

                // App Name
                Text(app.appName)
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer().frame(height: 8)

                // Short Description
                Text(app.shortDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 16)

                Spacer().frame(height: 24)

                // Install Button
                Button(action: onInstall) {
                    Text("설치하기")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 24)

                Spacer().frame(height: 8)

                // Dismiss Today Button
                Button(action: onDismissToday) {
                    Text("오늘 하루 보지 않기")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .padding(.horizontal, 24)

                // Close Button
                Button(action: onClose) {
                    Text("닫기")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .padding(.bottom, 20)
            }
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.regularMaterial)
            )
            .padding(.horizontal, 32)
        }
    }
}
