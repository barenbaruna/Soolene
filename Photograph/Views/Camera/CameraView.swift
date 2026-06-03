//
//  CameraView.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 18/05/26.
//

import AVFoundation
import SwiftUI

/// Main camera screen — full-screen layout with composition guides.
struct CameraView: View {
    @State private var viewModel = CameraViewModel()
    @State private var isShowingGallery = false
    @State private var isShowingSettingsTray = false

    var body: some View {
        let bindable = Bindable(viewModel)

        ZStack {
            // MARK: Layer 1 — Camera Preview

            CameraPreviewView(session: viewModel.cameraManager.session)
                .ignoresSafeArea()
                .task { await viewModel.onAppear() }
                .onDisappear { viewModel.onDisappear() }

            // MARK: Layer 2 — Composition Overlay

            CompositionOverlayView(
                composition: viewModel.resolvedComposition,
                geometry: viewModel.analysis.sceneGeometry,
                aspectRatio: viewModel.selectedAspectRatio,
                subjectOffset: viewModel.analysis.subjectOffset,
                isPerfect: viewModel.analysis.isCompositionPerfect
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // MARK: Layer 3 — HUD

            VStack(spacing: 0) {
                // Top: Settings toggle chevron & Guidance tip pill
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            isShowingSettingsTray.toggle()
                        }
                    } label: {
                        Image(systemName: isShowingSettingsTray ? "chevron.down" : "chevron.up")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .padding(8)
                            .glassCircle()
                    }
                    Spacer()
                }
                .padding(.top, 16)
                
                topGuidancePill
                    .padding(.top, 8)

                Spacer()

                // Countdown Timer Overlay
                if viewModel.isCountingDown {
                    Text("\(viewModel.countdownValue)")
                        .font(.system(size: 100, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(radius: 10)
                        .transition(.scale.combined(with: .opacity))
                    
                    Spacer()
                }

                // Lens selector
                if !viewModel.cameraManager.isUsingFrontCamera,
                   viewModel.cameraManager.availableLenses.count > 1,
                   !isShowingSettingsTray, !viewModel.isCountingDown
                {
                    LensSelectorView(
                        availableLenses: viewModel.cameraManager.availableLenses,
                        selectedLens: Binding(
                            get: { viewModel.cameraManager.selectedLens },
                            set: { viewModel.switchLens($0) }
                        )
                    )
                    .padding(.bottom, 8)
                }

                // Composition label
                if !isShowingSettingsTray && !viewModel.isCountingDown {
                    compositionPill
                        .padding(.bottom, 16)
                }

                // Bottom bar: Gallery - Capture - Switch Camera
                if !isShowingSettingsTray {
                    bottomBar
                        .padding(.bottom, 24)
                }
            }

            // Settings tray overlay (Slides up from bottom)
            if isShowingSettingsTray {
                VStack {
                    Spacer()
                    settingsTray
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        // Review Sheet
        .sheet(isPresented: bindable.isShowingReview) {
            if let image = viewModel.cameraManager.capturedImage {
                ReviewView(
                    image: image,
                    composition: viewModel.analysis.detectedComposition,
                    technique: viewModel.activeTechnique,
                    onSave: { Task { await viewModel.savePhoto() } },
                    onDismiss: { viewModel.dismissReview() }
                )
            }
        }
        // Gallery Sheet
        .fullScreenCover(isPresented: $isShowingGallery) {
            GalleryView()
        }
        // Auto-open review on capture
        .onChange(of: viewModel.cameraManager.capturedImage) { _, newImage in
            if newImage != nil {
                viewModel.isShowingReview = true
            }
        }
        .alert("Could Not Save", isPresented: Binding(
            get: { viewModel.saveError != nil },
            set: { if !$0 { viewModel.saveError = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.saveError = nil }
        } message: {
            Text(viewModel.saveError ?? "")
        }
    }

    // MARK: - Top Guidance Pill

    private var topGuidancePill: some View {
        Group {
            if let technique = viewModel.activeTechnique {
                Text(technique.tip)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .glassPill()
                    .padding(.horizontal, 40)
                    .animation(.spring(response: 0.5), value: technique.tip)
                    .id(technique.tip)
            }
        }
    }

    // MARK: - Composition Label Pill

    private var compositionPill: some View {
        HStack(spacing: 6) {
            Image(systemName: viewModel.resolvedComposition.symbolName)
                .font(.caption)
            Text(viewModel.compositionLabel)
                .font(.callout)
                .fontWeight(.medium)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .glassPill()
        .animation(.easeInOut(duration: 0.3), value: viewModel.compositionLabel)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(alignment: .center) {
            // Gallery button
            Button {
                isShowingGallery = true
            } label: {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .glassCircle()
            }
            .accessibilityLabel("Gallery")

            Spacer()

            // Capture button
            if viewModel.isCountingDown {
                Button(action: { viewModel.cancelCountdown() }) {
                    ZStack {
                        Circle().strokeBorder(.white, lineWidth: 3).frame(width: 76, height: 76)
                        Image(systemName: "stop.fill").font(.title).foregroundStyle(.white)
                    }
                }
            } else {
                CaptureButtonView { viewModel.capturePhoto() }
            }

            Spacer()

            // Switch camera button
            Button { viewModel.switchCamera() } label: {
                Image(systemName: "camera.rotate.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .glassCircle()
            }
            .accessibilityLabel("Switch Camera")
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Settings Tray

    private var settingsTray: some View {
        VStack(spacing: 0) {
            // Drag handle indicator
            Capsule()
                .fill(Color.secondary)
                .frame(width: 36, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 24)

            HStack(spacing: 24) {
                // Flash
                Button { viewModel.cycleFlash() } label: {
                    VStack(spacing: 8) {
                        Image(systemName: viewModel.flashSymbolName)
                            .font(.title)
                        Text("FLASH")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .frame(width: 64, height: 64)
                    .foregroundStyle(viewModel.cameraManager.flashMode != .off ? .yellow : .white)
                }
                
                // Timer
                Button { viewModel.cycleTimer() } label: {
                    VStack(spacing: 8) {
                        Image(systemName: viewModel.timerLength > 0 ? "timer" : "timer")
                            .font(.title)
                        Text(viewModel.timerLength > 0 ? "\(viewModel.timerLength)s" : "TIMER")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .frame(width: 64, height: 64)
                    .foregroundStyle(viewModel.timerLength > 0 ? .yellow : .white)
                }
                
                // Exposure
                Button { viewModel.cycleExposure() } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "plus.minus")
                            .font(.title)
                        let evStr = viewModel.cameraManager.exposureBias > 0 ? "+\(viewModel.cameraManager.exposureBias)" : "\(viewModel.cameraManager.exposureBias)"
                        Text(viewModel.cameraManager.exposureBias != 0 ? evStr : "EXPOSURE")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .frame(width: 64, height: 64)
                    .foregroundStyle(viewModel.cameraManager.exposureBias != 0 ? .yellow : .white)
                }

                // Aspect
                VStack(spacing: 8) {
                    AspectRatioButton(selectedRatio: Bindable(viewModel).selectedAspectRatio)
                        .scaleEffect(1.2)
                    Text("ASPECT")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 64, height: 64)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity)
        .settingsTrayBackground()
        .gesture(
            DragGesture().onEnded { value in
                if value.translation.height > 50 {
                    withAnimation(.spring(response: 0.3)) {
                        isShowingSettingsTray = false
                    }
                }
            }
        )
    }
}

// MARK: - Review View

struct ReviewView: View {
    let image: UIImage
    let composition: CompositionType
    let technique: CompositionTechnique?
    let onSave: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 16)

                        // Composition info
                        HStack(spacing: 16) {
                            Image(systemName: composition.symbolName)
                                .font(.title2)
                                .foregroundStyle(Color.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(composition.rawValue)
                                    .font(.headline)
                                Text(composition.shortDescription)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(16)
                        .reviewCard()
                        .padding(.horizontal, 16)

                        if let technique {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("GUIDANCE")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                Text(technique.tip)
                                    .font(.subheadline)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .reviewCard()
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Retake", role: .cancel) { onDismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        onSave()
                        onDismiss()
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                    .saveButtonStyle()
                }
            }
        }
    }
}

// MARK: - View Modifiers

private extension View {
    @ViewBuilder
    func glassPill() -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(in: .capsule)
        } else {
            self.background(.regularMaterial, in: Capsule())
        }
    }

    @ViewBuilder
    func glassCircle() -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular.interactive())
        } else {
            self.background(.regularMaterial, in: Circle())
        }
    }

    @ViewBuilder
    func reviewCard() -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(in: .rect(cornerRadius: 16))
        } else {
            self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    @ViewBuilder
    func saveButtonStyle() -> some View {
        if #available(iOS 26, *) {
            self.buttonStyle(.glassProminent).tint(.accentColor)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    func settingsTrayBackground() -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(in: .rect(cornerRadius: 20))
        } else {
            self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
    }
}
