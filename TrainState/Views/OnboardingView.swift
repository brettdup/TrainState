import SwiftUI
import SwiftData
import HealthKit

struct OnboardingView: View {
    @StateObject private var healthKitManager = HealthKitManager()
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentStep = 0
    @State private var isImporting = false
    @State private var importProgress: Double = 0.0
    @State private var showError = false
    @State private var errorMessage: String?
    @State private var animateIcon = false
    @State private var showContent = false
    @State private var isFinalizingRoutes = false
    
    // Add notification observer reference for proper cleanup
    @State private var notificationObserver: NSObjectProtocol?
    
    private let steps = [
        OnboardingStep(
            title: "Welcome to\nTrainState",
            description: "Your intelligent fitness companion that transforms how you track, analyze, and celebrate your workouts.",
            imageName: "figure.run",
            color: .blue,
            gradient: LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        OnboardingStep(
            title: "Smart Health\nIntegration",
            description: "Seamlessly sync with Apple Health to bring all your workout data together in one beautiful place.",
            imageName: "heart.fill",
            color: .green,
            gradient: LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        OnboardingStep(
            title: "Intelligent\nCategorization",
            description: "Automatically organize your workouts by type and discover patterns in your fitness journey.",
            imageName: "chart.bar.fill",
            color: .purple,
            gradient: LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        OnboardingStep(
            title: "Ready to\nTransform",
            description: "Your fitness journey starts now. Let's make every workout count.",
            imageName: "star.fill",
            color: .orange,
            gradient: LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dynamic background gradient
                AnimatedBackgroundView(step: currentStep)
                    .ignoresSafeArea()
                
                // Floating content card
                VStack(spacing: 0) {
                    // Custom progress indicator
                    ProgressRingsView(currentStep: currentStep, totalSteps: steps.count)
                        .padding(.top, 60)
                    
                    // Main content area
                    ZStack {
                        ForEach(0..<steps.count, id: \.self) { index in
                            StepContentView(
                                step: steps[index],
                                isActive: index == currentStep,
                                isImporting: isImporting,
                                importProgress: importProgress,
                                showImportUI: index == 1,
                                isFinalizingRoutes: isFinalizingRoutes
                            )
                            .opacity(index == currentStep ? 1 : 0)
                            .scaleEffect(index == currentStep ? 1 : 0.9)
                            .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.8, blendDuration: 0), value: currentStep)
                        }
                    }
                    .frame(maxHeight: .infinity)
                    
                    // Floating navigation
                    FloatingNavigationView(
                        currentStep: currentStep,
                        totalSteps: steps.count,
                        isImporting: isImporting,
                        stepColor: steps[currentStep].color,
                        onBack: { 
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                currentStep -= 1
                            }
                        },
                        onNext: {
                            if currentStep == 1 {
                                importWorkouts()
                            } else {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    currentStep += 1
                                }
                            }
                        },
                        onComplete: {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                hasCompletedOnboarding = true
                            }
                        }
                    )
                    .padding(.bottom, 40)
                }
            }
        }
        .alert("Import Error", isPresented: $showError) {
            Button("Continue Anyway") { 
                withAnimation {
                    currentStep += 1
                }
            }
            Button("Retry") { importWorkouts() }
        } message: {
            Text(errorMessage ?? "We couldn't import your workouts, but you can continue and set this up later in Settings.")
        }
        .onAppear {
            // Set up notification observer for import progress with proper cleanup
            notificationObserver = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ImportProgressUpdated"),
                object: nil,
                queue: .main
            ) { notification in
                if let progress = notification.userInfo?["progress"] as? Double {
                    withAnimation(.easeInOut) {
                        importProgress = progress
                    }
                }
            }
            
            // Animate in the content
            withAnimation(.easeOut(duration: 1.0).delay(0.5)) {
                showContent = true
            }
        }
        .onDisappear {
            // Clean up notification observer to prevent crashes
            if let observer = notificationObserver {
                NotificationCenter.default.removeObserver(observer)
                notificationObserver = nil
            }
        }
    }
    
    private func importWorkouts() {
        guard !isImporting else { return }
        
        withAnimation(.spring()) {
            isImporting = true
            importProgress = 0.0
            isFinalizingRoutes = false
        }
        
        Task {
            do {
                // First, request authorization
                let success = try await healthKitManager.requestAuthorizationAsync()
                if !success {
                    await MainActor.run {
                        errorMessage = "Please enable HealthKit access in Settings to import your workout history"
                        showError = true
                        isImporting = false
                    }
                    return
                }
                
                // Then import workouts with improved error handling
                try await HealthKitManager.shared.importWorkoutsToCoreData(
                    context: modelContext,
                    onRoutesStarted: {
                        DispatchQueue.main.async {
                            isFinalizingRoutes = true
                        }
                    },
                    onAllComplete: {
                        DispatchQueue.main.async {
                            isImporting = false
                            importProgress = 1.0
                            isFinalizingRoutes = false
                        }
                    }
                )
                
                await MainActor.run {
                    // Celebrate completion with haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            currentStep += 1
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    print("[Onboarding] Import error: \(error.localizedDescription)")
                    errorMessage = "Failed to import workouts: \(error.localizedDescription)"
                    showError = true
                    isImporting = false
                    importProgress = 0.0
                    isFinalizingRoutes = false
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct AnimatedBackgroundView: View {
    let step: Int
    @State private var animateGradient = false
    
    var body: some View {
        ZStack {
            // Base dark background
            Color.black
            
            // Animated gradient overlay
            RadialGradient(
                colors: gradientColors,
                center: .center,
                startRadius: 50,
                endRadius: animateGradient ? 800 : 400
            )
            .opacity(0.3)
            .blur(radius: 60)
            .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: animateGradient)
            
            // Subtle noise texture
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.8)
        }
        .onAppear {
            animateGradient = true
        }
        .onChange(of: step) { _, _ in
            withAnimation(.easeInOut(duration: 1)) {
                animateGradient.toggle()
            }
        }
    }
    
    private var gradientColors: [Color] {
        switch step {
        case 0: return [.blue, .cyan, .indigo]
        case 1: return [.green, .mint, .teal]
        case 2: return [.purple, .pink, .indigo]
        case 3: return [.orange, .red, .yellow]
        default: return [.blue, .cyan, .indigo]
        }
    }
}

struct ProgressRingsView: View {
    let currentStep: Int
    let totalSteps: Int
    @State private var animateProgress = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Main progress ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 4)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: animateProgress ? progress : 0)
                    .stroke(
                        AngularGradient(
                            colors: [.blue, .cyan, .purple, .pink],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 1, dampingFraction: 0.8), value: animateProgress)
                
                // Step indicator
                VStack(spacing: 2) {
                    Text("\(currentStep + 1)")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    Text("of \(totalSteps)")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            // Mini step indicators
            HStack(spacing: 12) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(index <= currentStep ? .white : .white.opacity(0.3))
                        .frame(width: index == currentStep ? 24 : 16, height: 4)
                        .animation(.spring(response: 0.6), value: currentStep)
                }
            }
        }
        .onAppear {
            animateProgress = true
        }
        .onChange(of: currentStep) { _, _ in
            withAnimation(.spring(response: 1, dampingFraction: 0.8)) {
                animateProgress = true
            }
        }
    }
    
    private var progress: Double {
        Double(currentStep + 1) / Double(totalSteps)
    }
}

struct StepContentView: View {
    let step: OnboardingStep
    let isActive: Bool
    let isImporting: Bool
    let importProgress: Double
    let showImportUI: Bool
    let isFinalizingRoutes: Bool
    @State private var iconScale: CGFloat = 0.8
    @State private var showText = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer(minLength: geometry.size.height * 0.04)
                
                // Animated icon with glow effect
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(step.gradient)
                        .frame(width: 140, height: 140)
                        .blur(radius: 20)
                        .opacity(0.6)
                    
                    // Icon background
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 120, height: 120)
                    
                    // Main icon
                    Image(systemName: step.imageName)
                        .font(.system(size: 54, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: step.color.opacity(0.8), radius: 8, x: 0, y: 0)
                        .scaleEffect(iconScale)
                        .animation(.spring(response: 0.8, dampingFraction: 0.6).repeatForever(autoreverses: true), value: iconScale)
                }
                .scaleEffect(isActive ? 1 : 0.8)
                .frame(height: 140)
                
                // Content card
                VStack(spacing: 20) {
                    Text(step.title)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .opacity(showText ? 1 : 0)
                        .offset(y: showText ? 0 : 20)
                        .minimumScaleFactor(0.7)
                        .lineLimit(2)
                        .layoutPriority(1)
                    
                    Text(step.description)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineSpacing(4)
                        .opacity(showText ? 1 : 0)
                        .offset(y: showText ? 0 : 20)
                    
                    // Import progress UI
                    if showImportUI {
                        ImportProgressView(
                            isImporting: isImporting,
                            isFinalizingRoutes: isFinalizingRoutes,
                            progress: importProgress,
                            gradient: step.gradient
                        )
                        .opacity(showText ? 1 : 0)
                        .offset(y: showText ? 0 : 20)
                        .animation(.easeOut(duration: 0.6).delay(0.8), value: showText)
                    }
                }
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity)
                
                Spacer(minLength: geometry.size.height * 0.10)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .onAppear {
            if isActive {
                iconScale = 1.05
                withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                    showText = true
                }
            }
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                iconScale = 1.05
                withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                    showText = true
                }
            } else {
                showText = false
                iconScale = 0.8
            }
        }
    }
}

struct ImportProgressView: View {
    let isImporting: Bool
    let isFinalizingRoutes: Bool
    let progress: Double
    let gradient: LinearGradient
    @State private var pulseAnimation = false
    @State private var rotationDegrees: Double = 0
    @State private var showParticles = false
    @State private var currentStatusIndex = 0
    @State private var showSuccess = false
    
    private let statusMessages = [
        "Connecting to HealthKit...",
        "Scanning workout history...",
        "Processing your data...",
        "Organizing workouts...",
        "Almost finished...",
        "Finalizing routes...",
        "Import complete! 🎉"
    ]
    
    var body: some View {
        VStack(spacing: 24) {
            if isImporting || showSuccess {
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
                        .stroke(.white.opacity(0.1), lineWidth: 8)
                        .frame(width: 120, height: 120)
                    
                    // Progress ring
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(gradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.8, dampingFraction: 0.8), value: progress)
                    
                    // Inner content
                    VStack(spacing: 4) {
                        if showSuccess {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundStyle(.white)
                                .shadow(color: .green.opacity(0.8), radius: 8, x: 0, y: 0)
                                .scaleEffect(showSuccess ? 1.2 : 0.8)
                                .animation(.spring(response: 0.6, dampingFraction: 0.6), value: showSuccess)
                        } else {
                            // Animated percentage
                            Text("\(Int(progress * 100))%")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .contentTransition(.numericText())
                                .animation(.easeOut(duration: 0.3), value: progress)
                            
                            // Spinning activity indicator
                            Circle()
                                .stroke(gradient, lineWidth: 2)
                                .frame(width: 20, height: 20)
                                .rotationEffect(.degrees(rotationDegrees))
                                .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: rotationDegrees)
                        }
                    }
                    
                    // Particle effects for completion
                    if showSuccess {
                        ParticleEffectView()
                    }
                }
                
                // Status message with typewriter effect
                VStack(spacing: 12) {
                    Text(currentStatusMessage)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .opacity(0.9)
                        .animation(.easeInOut(duration: 0.3), value: currentStatusMessage)
                    
                    // Detailed progress info
                    if !showSuccess && isImporting {
                        HStack(spacing: 16) {
                            // Data processing indicator
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(gradient)
                                    .frame(width: 6, height: 6)
                                    .scaleEffect(pulseAnimation ? 1.5 : 1.0)
                                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true).delay(0), value: pulseAnimation)
                                
                                Circle()
                                    .fill(gradient.opacity(0.7))
                                    .frame(width: 6, height: 6)
                                    .scaleEffect(pulseAnimation ? 1.5 : 1.0)
                                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true).delay(0.2), value: pulseAnimation)
                                
                                Circle()
                                    .fill(gradient.opacity(0.5))
                                    .frame(width: 6, height: 6)
                                    .scaleEffect(pulseAnimation ? 1.5 : 1.0)
                                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true).delay(0.4), value: pulseAnimation)
                            }
                            
                            Text("Processing data securely")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    
                    // Success message
                    if showSuccess {
                        VStack(spacing: 8) {
                            Text("Your workouts are ready!")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("We've successfully imported your fitness history")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .scale(scale: 1.2).combined(with: .opacity)
                        ))
                    }
                }
                
                // Mini stats preview (when importing)
                if isImporting && progress > 0.3 && !showSuccess {
                    HStack(spacing: 20) {
                        StatPreviewItem(
                            icon: "figure.run",
                            label: "Workouts",
                            value: "\(Int(progress * 247))",
                            gradient: gradient
                        )
                        
                        StatPreviewItem(
                            icon: "calendar",
                            label: "Days",
                            value: "\(Int(progress * 89))",
                            gradient: gradient
                        )
                        
                        StatPreviewItem(
                            icon: "flame.fill",
                            label: "Activities",
                            value: "\(Int(progress * 12))",
                            gradient: gradient
                        )
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                }
            }
        }
        .padding(.top, 20)
        .onAppear {
            pulseAnimation = true
            rotationDegrees = 360
            updateStatusMessage()
        }
        .onChange(of: progress) { _, _ in
            updateStatusMessage()
            checkForCompletion()
        }
        .onChange(of: isFinalizingRoutes) { _, _ in
            checkForCompletion()
        }
    }
    
    private var currentStatusMessage: String {
        if showSuccess {
            return statusMessages.last ?? "Complete!"
        } else if isFinalizingRoutes {
            return statusMessages[5] // "Finalizing routes..."
        } else {
            return statusMessages[currentStatusIndex]
        }
    }
    
    private func updateStatusMessage() {
        guard !showSuccess else { return }
        
        let newIndex: Int
        switch progress {
        case 0.0..<0.1:
            newIndex = 0
        case 0.1..<0.3:
            newIndex = 1
        case 0.3..<0.6:
            newIndex = 2
        case 0.6..<0.85:
            newIndex = 3
        case 0.85..<1.0:
            newIndex = 4
        default:
            newIndex = 4
        }
        
        if newIndex != currentStatusIndex {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStatusIndex = newIndex
            }
        }
    }
    
    private func checkForCompletion() {
        if progress >= 1.0 && !isFinalizingRoutes && !showSuccess {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                    showSuccess = true
                }
                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                impactFeedback.impactOccurred()
            }
        }
    }
}

struct StatPreviewItem: View {
    let icon: String
    let label: String
    let value: String
    let gradient: LinearGradient
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .green.opacity(0.6), radius: 4, x: 0, y: 0)
            
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .contentTransition(.numericText())
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct ParticleEffectView: View {
    @State private var particles: [ParticleData] = []
    
    var body: some View {
        ZStack {
            ForEach(particles, id: \.id) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .offset(x: particle.x, y: particle.y)
                    .opacity(particle.opacity)
                    .scaleEffect(particle.scale)
            }
        }
        .onAppear {
            createParticles()
        }
    }
    
    private func createParticles() {
        particles = []
        
        for i in 0..<20 {
            let particle = ParticleData(
                id: i,
                x: CGFloat.random(in: -60...60),
                y: CGFloat.random(in: -60...60),
                size: CGFloat.random(in: 3...8),
                color: [Color.blue, Color.cyan, Color.purple, Color.pink].randomElement()!,
                opacity: Double.random(in: 0.6...1.0),
                scale: 0.1
            )
            particles.append(particle)
        }
        
        // Animate particles
        withAnimation(.easeOut(duration: 1.5)) {
            for i in particles.indices {
                particles[i].scale = 1.0
                particles[i].opacity = 0.0
                particles[i].x *= 2
                particles[i].y *= 2
            }
        }
    }
}

struct ParticleData {
    let id: Int
    var x: CGFloat
    var y: CGFloat
    let size: CGFloat
    let color: Color
    var opacity: Double
    var scale: CGFloat
}

struct FloatingNavigationView: View {
    let currentStep: Int
    let totalSteps: Int
    let isImporting: Bool
    let stepColor: Color
    let onBack: () -> Void
    let onNext: () -> Void
    let onComplete: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Back button
            if currentStep > 0 {
                Button(action: onBack) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            }
            
            Spacer()
            
            // Next/Complete button
            Button(action: currentStep < totalSteps - 1 ? onNext : onComplete) {
                HStack(spacing: 12) {
                    if isImporting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    
                    Text(buttonTitle)
                        .font(.system(size: 16, weight: .semibold))
                    
                    if !isImporting && currentStep < totalSteps - 1 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .semibold))
                    } else if currentStep == totalSteps - 1 {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [stepColor, stepColor.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: Capsule()
                )
                .shadow(color: stepColor.opacity(0.5), radius: 20, x: 0, y: 10)
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(isImporting)
        }
        .padding(.horizontal, 32)
    }
    
    private var buttonTitle: String {
        if isImporting {
            return "Importing..."
        } else if currentStep == 1 {
            return "Import Workouts"
        } else if currentStep < totalSteps - 1 {
            return "Continue"
        } else {
            return "Get Started"
        }
    }
}

struct OnboardingStep {
    let title: String
    let description: String
    let imageName: String
    let color: Color
    let gradient: LinearGradient
}

#Preview {
    OnboardingView()
        .modelContainer(for: UserSettings.self, inMemory: true)
} 
