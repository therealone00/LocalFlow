import SwiftUI

public struct AudioWaveformView: View {
    public let level: Float
    public let isProcessing: Bool
    
    @State private var phase: CGFloat = 0.0
    
    private let barCount = 5
    private let multipliers: [CGFloat] = [0.4, 0.8, 1.0, 0.7, 0.5]
    
    public init(level: Float, isProcessing: Bool = false) {
        self.level = level
        self.isProcessing = isProcessing
    }
    
    public var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 3, height: barHeight(for: index))
                    .animation(.spring(response: 0.15, dampingFraction: 0.6), value: level)
            }
        }
        .frame(height: 20)
        .onAppear {
            if isProcessing {
                withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                    phase = 1.0
                }
            }
        }
    }
    
    private func barHeight(for index: CGFloat.IntegerLiteralType) -> CGFloat {
        if isProcessing {
            // Pulsing wave during processing
            let wave = sin(Double(index) * 0.8 + Double(phase * .pi * 2))
            return CGFloat(6 + wave * 4)
        }
        
        let baseHeight: CGFloat = 4
        let dynamicHeight = CGFloat(level) * 16 * multipliers[index]
        return min(20, max(baseHeight, dynamicHeight))
    }
}
