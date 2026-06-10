import SwiftUI

struct TermsOfUseView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.accentColor.opacity(colorScheme == .dark ? 0.24 : 0.10),
                    ThemeColor.primaryUi02().opacity(colorScheme == .dark ? 0.35 : 0.65),
                    ThemeColor.primaryUi01()
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                GlassEffectContainerWrapper(spacing: 16) {
                    VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Terms of Use")
                            .font(.title2.weight(.bold))
                        Text("Last Updated: June 17, 2024")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()

                    termsSection("1. Acceptance of Terms", "By accessing and using Exercise Pal, you agree to be bound by these Terms of Use and all applicable laws and regulations.")
                    termsSection("2. Subscription Terms", "Exercise Pal offers premium features through auto-renewable subscriptions. Subscriptions automatically renew unless auto-renew is turned off at least 24 hours before the end of the current period. You can manage and cancel your subscriptions by going to your App Store account settings after purchase.")
                    termsSection("3. User Content", "You retain all rights to your workout data. By using Exercise Pal, you grant us a license to store and process your data to provide the service.")
                    termsSection("4. Privacy", "Your privacy is important to us. Please review our Privacy Policy to understand how we collect, use, and protect your information.")
                    termsSection("5. Disclaimer", "Exercise Pal is provided 'as is' without any warranties. We are not responsible for any injuries or health issues that may result from using the app.")
                    termsSection("6. Limitation of Liability", "We shall not be liable for any indirect, incidental, special, consequential, or punitive damages resulting from your use of Exercise Pal.")
                    termsSection("7. Changes to Terms", "We reserve the right to modify these terms at any time. We will notify users of any material changes.")
                    termsSection("8. Contact Information", "For questions about these Terms of Use, please contact us at support@trainstate.app")
                }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Terms of Use")
        .navigationBarTitleDisplayMode(.inline)
    }
    private func termsSection(_ title: String, _ content: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            Text(content)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}

#Preview {
    NavigationView {
        TermsOfUseView()
    }
} 
