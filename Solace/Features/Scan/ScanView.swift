//
//  ScanView.swift
//  Solace
//

import AVFoundation
import SwiftUI
import UIKit

struct ScanView: View {
    @FocusState private var barcodeFocused: Bool
    @State private var isVisible = false
    @State private var scannedBarcode: String?
    @State private var manualBarcode = ""
    @State private var showManualEntry = false

    private var normalizedBarcode: String { manualBarcode.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isValidBarcode: Bool {
        [8, 12, 13, 14].contains(normalizedBarcode.count) && normalizedBarcode.allSatisfy { $0.isASCII && $0.isNumber }
    }

    private var isCameraAccessDenied: Bool {
        [.denied, .restricted].contains(AVCaptureDevice.authorizationStatus(for: .video))
    }

    var body: some View {
        NavigationStack {
            Group {
                if BarcodeScannerAvailability.isSupported {
                    ZStack {
                        BarcodeScannerView(isScanning: isVisible && scannedBarcode == nil && !showManualEntry) { barcode in
                            guard scannedBarcode == nil else { return }
                            scannedBarcode = barcode
                        }
                        .ignoresSafeArea(edges: .bottom)

                        VStack {
                            Text("Point your camera at a barcode")
                                .font(.solaceCaption)
                                .foregroundStyle(.white)
                                .padding(.horizontal, Spacing.md)
                                .padding(.vertical, Spacing.sm)
                                .background(.black.opacity(0.55), in: Capsule())
                                .padding(.top, Spacing.lg)
                            Spacer()
                        }

                        VStack {
                            Spacer()
                            Button {
                                showManualEntry = true
                            } label: {
                                Label("Enter Barcode Manually", systemImage: "keyboard")
                                    .font(.system(.body, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, Spacing.lg)
                                    .padding(.vertical, Spacing.md)
                                    .background(.ultraThinMaterial, in: Capsule())
                                    .environment(\.colorScheme, .dark)
                            }
                            .padding(.bottom, Spacing.xl)
                        }
                    }
                } else if isCameraAccessDenied {
                    ContentUnavailableView {
                        Label("Camera Access Needed", systemImage: "barcode.viewfinder")
                    } description: {
                        Text("Solace needs camera access to scan barcodes. Enable it in Settings, or enter a barcode manually instead.")
                    } actions: {
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .buttonStyle(.solacePrimary())
                    }
                    .safeAreaInset(edge: .bottom) {
                        Button("Enter Barcode Manually") { showManualEntry = true }
                            .buttonStyle(.solaceSecondary())
                            .padding()
                    }
                } else {
                    ContentUnavailableView(
                        "Camera Scanning Unavailable",
                        systemImage: "barcode.viewfinder",
                        description: Text("This device or simulator doesn't support live barcode scanning. Enter a barcode manually instead.")
                    )
                    .safeAreaInset(edge: .bottom) {
                        Button("Enter Barcode Manually") { showManualEntry = true }
                            .buttonStyle(.solacePrimary())
                            .padding()
                    }
                }
            }
            .navigationTitle("Scan")
            .onAppear { isVisible = true }
            .onDisappear { isVisible = false }
            .navigationDestination(item: $scannedBarcode) { barcode in
                ProductDetailView(barcode: barcode)
            }
            .sheet(isPresented: $showManualEntry) {
                manualEntrySheet
            }
        }
    }

    private var manualEntrySheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Barcode digits", text: $manualBarcode)
                        .focused($barcodeFocused)
                        .accessibilityIdentifier("scan.barcode")
                        .keyboardType(.numberPad)
                } footer: {
                    Text("Type the 8, 12, 13, or 14 digits printed under the barcode on the package.")
                }
            }
            .task {
                // A single `Task.yield()` isn't enough for the field to be
                // focusable the instant the sheet's presentation animation
                // starts — retry for a bit so focus reliably lands without
                // requiring an extra tap.
                for _ in 0..<20 {
                    barcodeFocused = true
                    try? await Task.sleep(for: .milliseconds(50))
                }
            }
            .navigationTitle("Enter Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showManualEntry = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Look Up") {
                        barcodeFocused = false
                        scannedBarcode = normalizedBarcode
                        showManualEntry = false
                        manualBarcode = ""
                    }
                    .disabled(!isValidBarcode)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    ScanView()
}
