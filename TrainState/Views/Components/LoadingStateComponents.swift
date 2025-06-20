import SwiftUI

// MARK: - Loading State Components

/// A standardized loading overlay that can be used across the app
struct StandardLoadingOverlay: View {
    let message: String
    let showBackground: Bool
    
    init(message: String = "Loading...", showBackground: Bool = true) {
        self.message = message
        self.showBackground = showBackground
    }
    
    var body: some View {
        ZStack {
            if showBackground {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
            }
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.primary)
                
                Text(message)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Please wait...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(radius: 20)
            )
        }
    }
}

/// A loading card for list items or sections
struct LoadingCard: View {
    let message: String
    let compact: Bool
    
    init(message: String = "Loading...", compact: Bool = false) {
        self.message = message
        self.compact = compact
    }
    
    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: compact ? 8 : 12) {
                ProgressView()
                    .scaleEffect(compact ? 0.8 : 1.0)
                
                Text(message)
                    .font(compact ? .caption : .subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(compact ? 16 : 24)
            Spacer()
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
}

/// A loading state for button actions
struct LoadingButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void
    var disabled: Bool = false
    
    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                } else {
                    Text(title)
                }
            }
            .frame(minWidth: 120)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isLoading || disabled)
    }
}

/// A sophisticated loading progress view with animations
struct AnimatedLoadingView: View {
    let title: String
    let subtitle: String?
    let progress: Double?
    let gradient: LinearGradient
    
    @State private var pulseAnimation = false
    @State private var rotationDegrees: Double = 0
    
    init(
        title: String,
        subtitle: String? = nil,
        progress: Double? = nil,
        gradient: LinearGradient = LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
    ) {
        self.title = title
        self.subtitle = subtitle
        self.progress = progress
        self.gradient = gradient
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Main progress container
            ZStack {
                // Outer glow ring
                Circle()
                    .stroke(gradient.opacity(0.3), lineWidth: 12)
                    .frame(width: 140, height: 140)
                    .blur(radius: 8)
                    .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulseAnimation)
                
                // Background ring
                Circle()
                    .stroke(.primary.opacity(0.1), lineWidth: 8)
                    .frame(width: 120, height: 120)
                
                if let progress = progress {
                    // Progress ring
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(gradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.8, dampingFraction: 0.8), value: progress)
                }
                
                // Inner content
                VStack(spacing: 4) {
                    if let progress = progress {
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .contentTransition(.numericText())
                            .animation(.easeOut(duration: 0.3), value: progress)
                    } else {
                        // Spinning activity indicator
                        Circle()
                            .stroke(gradient, lineWidth: 3)
                            .frame(width: 24, height: 24)
                            .rotationEffect(.degrees(rotationDegrees))
                            .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: rotationDegrees)
                    }
                }
            }
            
            // Text content
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .onAppear {
            pulseAnimation = true
            rotationDegrees = 360
        }
    }
}

/// A simple inline loading indicator for text fields and small areas
struct InlineLoadingView: View {
    let message: String?
    let size: CGFloat
    
    init(message: String? = nil, size: CGFloat = 16) {
        self.message = message
        self.size = size
    }
    
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(size / 16)
            
            if let message = message {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

/// A loading state view for empty or error states
struct StateView: View {
    enum StateType {
        case loading(String)
        case empty(String, String?)
        case error(String, String?, () -> Void)
        case success(String, String?)
        
        var icon: String {
            switch self {
            case .loading: return "ellipsis"
            case .empty: return "tray"
            case .error: return "exclamationmark.triangle"
            case .success: return "checkmark.circle"
            }
        }
        
        var color: Color {
            switch self {
            case .loading: return .blue
            case .empty: return .secondary
            case .error: return .red
            case .success: return .green
            }
        }
    }
    
    let state: StateType
    
    var body: some View {
        VStack(spacing: 16) {
            iconView
                .foregroundColor(state.color)
            
            textContent
            
            actionButton
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private var iconView: some View {
        switch state {
        case .loading:
            ProgressView()
                .scaleEffect(1.2)
        default:
            Image(systemName: state.icon)
                .font(.system(size: 48, weight: .light))
        }
    }
    
    @ViewBuilder
    private var textContent: some View {
        VStack(spacing: 8) {
            switch state {
            case .loading(let message):
                Text(message)
                    .font(.headline)
                    .foregroundColor(.primary)
            case .empty(let title, let subtitle):
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            case .error(let title, let subtitle, _):
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            case .success(let title, let subtitle):
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
    
    @ViewBuilder
    private var actionButton: some View {
        if case .error(_, _, let action) = state {
            Button(action: action) {
                Label("Retry", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        } else {
            EmptyView()
        }
    }
}

// MARK: - Loading State Management Protocol

protocol LoadingStateManaging: ObservableObject {
    var isLoading: Bool { get set }
    var loadingMessage: String { get set }
    var errorMessage: String? { get set }
    
    func setLoading(_ loading: Bool, message: String)
    func setError(_ error: Error)
    func clearError()
}

extension LoadingStateManaging {
    func setLoading(_ loading: Bool, message: String = "Loading...") {
        DispatchQueue.main.async {
            self.isLoading = loading
            self.loadingMessage = message
            if loading {
                self.errorMessage = nil
            }
        }
    }
    
    func setError(_ error: Error) {
        DispatchQueue.main.async {
            self.isLoading = false
            self.errorMessage = error.localizedDescription
        }
    }
    
    func clearError() {
        DispatchQueue.main.async {
            self.errorMessage = nil
        }
    }
}

// MARK: - View Modifiers

struct LoadingStateModifier: ViewModifier {
    let isLoading: Bool
    let message: String
    let showBackground: Bool
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(isLoading)
                .opacity(isLoading ? 0.6 : 1.0)
            
            if isLoading {
                StandardLoadingOverlay(message: message, showBackground: showBackground)
            }
        }
    }
}

extension View {
    func loadingOverlay(
        isLoading: Bool,
        message: String = "Loading...",
        showBackground: Bool = true
    ) -> some View {
        modifier(LoadingStateModifier(
            isLoading: isLoading,
            message: message,
            showBackground: showBackground
        ))
    }
}

// MARK: - Preview Helpers

#Preview("Loading States") {
    ScrollView {
        VStack(spacing: 32) {
            Group {
                LoadingCard(message: "Loading workouts...")
                
                StateView(state: .loading("Syncing data..."))
                
                StateView(state: .empty("No workouts", "Add your first workout to get started"))
                
                StateView(state: .error("Connection failed", "Check your internet connection") { 
                    // Retry action
                })
                
                AnimatedLoadingView(
                    title: "Importing workouts",
                    subtitle: "This may take a moment...",
                    progress: 0.7
                )
            }
            .padding(.horizontal)
        }
    }
} 