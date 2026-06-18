//
//  PreTutorialOnboardingView.swift
//  Photograph
//

import SwiftUI

struct PreTutorialOnboardingView: View {
    @Environment(OnboardingStore.self) private var onboarding

    @State private var selection = OnboardingSlide.slides.first?.id ?? UUID()
    @State private var cameraStatus: PermissionStatus = .notDetermined
    @State private var photoStatus: PermissionStatus = .notDetermined
    @State private var isRequestingPermissions = false
    @State private var permissionAlert: PermissionAlertKind?

    private let slides = OnboardingSlide.slides
    private var currentSlideIndex: Int {
        slides.firstIndex(where: { $0.id == selection }) ?? 0
    }

    private var isLastSlide: Bool {
        currentSlideIndex == slides.count - 1
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: Spacing.small) {
                TabView(selection: $selection) {
                    ForEach(slides) { slide in
                        slidePage(slide)
                            .tag(slide.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .overlay(alignment: .bottom) {
                    OnboardingPageControl(
                        pageCount: slides.count,
                        currentIndex: currentSlideIndex
                    )
                    .padding(.bottom, Spacing.medium)
                }

                Button(action: startPermissionFlow) {
                    HStack(spacing: Spacing.small) {
                        if isRequestingPermissions {
                            ProgressView()
                                .tint(.white)
                        }

                        Text("Start Tutorial")
                            .frame(maxWidth: .infinity)
                    }
                    .font(Typography.buttonCTA)
                    .foregroundStyle(.white)
                    .frame(height: 50)
                    .background(isLastSlide ? AppColors.primary : Color.gray.opacity(0.42))
                    .clipShape(Capsule())
                }
                .disabled(isRequestingPermissions || !isLastSlide)
                .padding(.horizontal, Spacing.standard)
                .padding(.bottom, Spacing.medium)
            }
            .frame(maxWidth: 480)
        }
        .task {
            await refreshPermissions()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { await refreshPermissions() }
        }
        .alert(permissionAlertTitle, isPresented: Binding(
            get: { permissionAlert != nil },
            set: { if !$0 { permissionAlert = nil } }
        )) {
            Button("Open Settings") {
                PrivacyPermissionService.openSettings()
                permissionAlert = nil
            }
            Button("Not Now", role: .cancel) {
                permissionAlert = nil
            }
        } message: {
            Text(permissionAlertMessage)
        }
    }

    private func slidePage(_ slide: OnboardingSlide) -> some View {
        VStack(spacing: Spacing.standard) {
            Spacer(minLength: Spacing.small)

            slideHeader(slide)
                .frame(height: 64)
                .padding(.horizontal, Spacing.medium)

            Image(slide.imageName)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .aspectRatio(0.54, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous))
                .clipped()
                .padding(.horizontal, Spacing.small)
                .accessibilityHidden(true)

            Spacer(minLength: 0)
        }
    }

    private func slideHeader(_ slide: OnboardingSlide) -> some View {
        VStack(spacing: Spacing.small) {
            Text(slide.title)
                .font(Typography.headline)
                .foregroundStyle(.black)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            if let subtitle = slide.subtitle {
                Text(subtitle)
                    .font(Typography.caption)
                    .foregroundStyle(.black.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var permissionAlertTitle: String {
        switch permissionAlert {
        case .camera:
            return "Turn On Camera Access"
        case .gallery:
            return "Turn On Photo Library Access"
        case nil:
            return ""
        }
    }

    private var permissionAlertMessage: String {
        switch permissionAlert {
        case .camera:
            return PrivacyPermissionService.cameraSettingsMessage
        case .gallery:
            return PrivacyPermissionService.photoLibrarySettingsMessage
        case nil:
            return ""
        }
    }

    private func startPermissionFlow() {
        guard !isRequestingPermissions else { return }

        Task { @MainActor in
            isRequestingPermissions = true
            defer { isRequestingPermissions = false }

            await refreshPermissions()

            if !cameraStatus.allowsCamera {
                cameraStatus = await PrivacyPermissionService.requestCameraAccess()
            }

            guard cameraStatus.allowsCamera else {
                permissionAlert = .camera
                return
            }

            photoStatus = PrivacyPermissionService.photoReadStatus()
            if !photoStatus.allowsPhotoBrowse {
                photoStatus = await PrivacyPermissionService.requestPhotoReadAccess()
            }

            guard photoStatus.allowsPhotoBrowse else {
                permissionAlert = .gallery
                return
            }

            onboarding.completePreTutorialOnboarding()
        }
    }

    @MainActor
    private func refreshPermissions() async {
        cameraStatus = PrivacyPermissionService.cameraStatus()
        photoStatus = PrivacyPermissionService.photoReadStatus()
    }
}

private struct OnboardingSlide: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let imageName: String

    init(title: String, subtitle: String? = nil, imageName: String) {
        self.title = title
        self.subtitle = subtitle
        self.imageName = imageName
    }

    static let slides = [
        OnboardingSlide(
            title: "Set Your Main Object",
            subtitle: "Long press to lock your object before shooting",
            imageName: "Onboarding1"
        ),
        OnboardingSlide(
            title: "Discover the Right Composition",
            subtitle: "Use the best suggestion or explore your own",
            imageName: "Onboarding2"
        ),
        OnboardingSlide(
            title: "Refine your framing with guided composition support",
            imageName: "Onboarding3"
        )
    ]
}

private enum PermissionAlertKind {
    case camera
    case gallery
}

private struct OnboardingPageControl: View {
    let pageCount: Int
    let currentIndex: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { index in
                Capsule()
                    .fill(index == currentIndex ? Color.black : Color.black.opacity(0.28))
                    .frame(width: index == currentIndex ? 9 : 8, height: 8)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            if #available(iOS 26, *) {
                Capsule()
                    .fill(Color.clear)
                    .glassEffect(.regular, in: .capsule)
            } else {
                Capsule()
                    .fill(.ultraThinMaterial)
            }
        }
        .accessibilityLabel("Page \(currentIndex + 1) of \(pageCount)")
    }
}

#Preview {
    PreTutorialOnboardingView()
        .environment(OnboardingStore())
}
