import SwiftUI

func monoLabel(_ text: String, color: Color = HuginColor.asche, size: CGFloat = 11) -> some View {
    monoText(text.uppercased(), size: size, color: color)
}

func monoText(_ text: String, size: CGFloat, color: Color) -> some View {
    Text(text).font(HuginFont.geistMono(size)).foregroundStyle(color)
        .tracking(1.4)
}
