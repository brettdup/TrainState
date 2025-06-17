import SwiftUI

struct TermsOfUseView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Terms of Use")
                    .font(.title)
                    .fontWeight(.bold)
                
                Group {
                    Text("Last Updated: June 17, 2024")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("1. Acceptance of Terms")
                        .font(.headline)
                    Text("By accessing and using TrainState, you agree to be bound by these Terms of Use and all applicable laws and regulations.")
                    
                    Text("2. Subscription Terms")
                        .font(.headline)
                    Text("TrainState offers premium features through auto-renewable subscriptions. Subscriptions automatically renew unless auto-renew is turned off at least 24 hours before the end of the current period. You can manage and cancel your subscriptions by going to your App Store account settings after purchase.")
                    
                    Text("3. User Content")
                        .font(.headline)
                    Text("You retain all rights to your workout data. By using TrainState, you grant us a license to store and process your data to provide the service.")
                    
                    Text("4. Privacy")
                        .font(.headline)
                    Text("Your privacy is important to us. Please review our Privacy Policy to understand how we collect, use, and protect your information.")
                    
                    Text("5. Disclaimer")
                        .font(.headline)
                    Text("TrainState is provided 'as is' without any warranties. We are not responsible for any injuries or health issues that may result from using the app.")
                    
                    Text("6. Limitation of Liability")
                        .font(.headline)
                    Text("We shall not be liable for any indirect, incidental, special, consequential, or punitive damages resulting from your use of TrainState.")
                    
                    Text("7. Changes to Terms")
                        .font(.headline)
                    Text("We reserve the right to modify these terms at any time. We will notify users of any material changes.")
                    
                    Text("8. Contact Information")
                        .font(.headline)
                    Text("For questions about these Terms of Use, please contact us at support@trainstate.app")
                }
            }
            .padding()
        }
        .navigationTitle("Terms of Use")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        TermsOfUseView()
    }
} 