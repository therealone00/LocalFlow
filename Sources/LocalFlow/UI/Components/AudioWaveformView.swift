import SwiftUI

public struct AudioWaveformView: View {
    public let level: Float
    public let isProcessing: Bool
    
    @State private var phase: CGFloat = 0.0
    
    private let barCount = 7
    private let multipliers: [CGFloat] = [0.35, 0.65, 0.95, 1.0, 0.85, 0.55, 0.3]
    
    // Dynamic Apple Intelligence / Wispr Flow gradient
    private let gradient = LinearGradient(
        colors: [
            Color(red: 1.0, green: 0.42, blue: 0.28), // Vibrant Coral
            Color(red: 0.72, green: 0.25, blue: 1.0),  // Neon Violet
            Color(red: 0.15, green: 0.78, blue: 1.0)   // Electric Cyan
        ],
        startPoint: .bottom,
        endPoint: .top
    )
    
    private let processingGradient = LinearGradient(
        colors: [
            Color(red: 0.2, green: 0.8, blue: 1.0),
            Color(red: 0.65, green: 0.35, blue: 1.0),
            Color(red: 1.0, green: 0.3, blue: 0.6)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    public init(level: Float, isProcessing: Bool = false) {
        self.level = level
        self.isProcessing = isProcessing
    }
    
    public var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(isProcessing ? AnyShapeStyle(processingGradient) : AnyShapeStyle(gradient))
                    .frame(width: 3.5, height: barHeight(for: index))
                    .shadow(color: isProcessing ? Color.purple.opacity(0.4) : Color(red: 1.0, green: 0.4, blue: 0.3).opacity(0.4), radius: 3, x: 0, y: 0)
                    .animation(.spring(response: 0.18, dampingFraction: 0.58), value: level)
            }
        }
        .frame(height: 24)
        .onAppear {
            if isProcessing {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    phase = 1.0
                }
            }
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        if isProcessing {
            let offset = sin(Double(index) * 0.9 + Double(phase * .pi * 2))
            return CGFloat(7 + offset * 6)
        }
        
        let baseHeight: CGFloat = 5
        let dynamicHeight = CGFloat(level) * 20 * multipliers[index]
        return min(24, max(baseHeight, dynamicHeight))
    }
}
