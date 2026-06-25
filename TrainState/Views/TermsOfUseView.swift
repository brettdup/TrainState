import SwiftUI

struct TermsOfUseView: View {
    var body: some View {
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
                    linkSection("3. Apple Standard EULA", "Exercise Pal uses Apple's standard Terms of Use (EULA).", "View Terms of Use (EULA)", LegalLinks.standardAppleEULA)
                    termsSection("4. User Content", "You retain all rights to your workout data. By using Exercise Pal, you grant us a license to store and process your data to provide the service.")
                    termsSection("5. Privacy", "Your privacy is important to us. Please review our Privacy Policy to understand how we collect, use, and protect your information.")
                    termsSection("6. Disclaimer", "Exercise Pal is provided 'as is' without any warranties. We are not responsible for any injuries or health issues that may result from using the app.")
                    termsSection("7. Limitation of Liability", "We shall not be liable for any indirect, incidental, special, consequential, or punitive damages resulting from your use of Exercise Pal.")
                    termsSection("8. Changes to Terms", "We reserve the right to modify these terms at any time. We will notify users of any material changes.")
                    termsSection("9. Contact Information", "For questions about these Terms of Use, please contact us at support@trainstate.app")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
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

    private func linkSection(_ title: String, _ content: String, _ linkTitle: String, _ url: URL) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            Text(content)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Link(linkTitle, destination: url)
                .font(.subheadline.weight(.semibold))
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
