import SwiftUI

struct ToastView: View {
    let message: ToastMessage

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: message.style.icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(message.style.color)

            Text(message.text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(hex: "#1A1A2E").opacity(0.95))
                RoundedRectangle(cornerRadius: 14)
                    .stroke(message.style.color.opacity(0.35), lineWidth: 1)
                RoundedRectangle(cornerRadius: 14)
                    .fill(message.style.color.opacity(0.05))
            }
        )
        .shadow(color: message.style.color.opacity(0.2), radius: 12)
        .padding(.horizontal, 20)
    }
}

struct AppBackground: View {
    @State private var animateGradient = false

    var body: some View {
        ZStack {
            Color(hex: "#0a0a10")
                .ignoresSafeArea()

            RadialGradient(
                colors: [Color(hex: "#7C5CFC").opacity(0.08), Color.clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 400
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Color(hex: "#5CF0FC").opacity(0.05), Color.clear],
                center: .bottomLeading,
                startRadius: 0,
                endRadius: 350
            )
            .ignoresSafeArea()

            Canvas { context, size in
                let dotSize: CGFloat = 1
                let spacing: CGFloat = 36
                context.opacity = 0.12
                var x: CGFloat = 0
                while x < size.width {
                    var y: CGFloat = 0
                    while y < size.height {
                        context.fill(
                            Path(ellipseIn: CGRect(x: x, y: y, width: dotSize, height: dotSize)),
                            with: .color(Color(hex: "#4A4A6A"))
                        )
                        y += spacing
                    }
                    x += spacing
                }
            }
            .ignoresSafeArea()
        }
    }
}
