//
//  ScanView.swift
//  Solace
//

import SwiftUI

struct ScanView: View {
    @State private var scannedBarcode: String?
    @State private var manualBarcode = ""
    @State private var showManualEntry = false

    var body: some View {
        NavigationStack {
            Group {
                if BarcodeScannerAvailability.isSupported {
                    BarcodeScannerView(isScanning: scannedBarcode == nil) { barcode in
                        guard scannedBarcode == nil else { return }
                        scannedBarcode = barcode
                    }
                    .ignoresSafeArea(edges: .bottom)
                    .overlay(alignment: .bottom) {
                        Button("Enter Barcode Manually") { showManualEntry = true }
                            .buttonStyle(.borderedProminent)
                            .tint(.solaceVitality)
                            .padding(.bottom, Spacing.xl)
                    }
                } else {
                    ContentUnavailableView(
                        "Camera Scanning Unavailable",
                        systemImage: "barcode.viewfinder",
                        description: Text("This device or simulator doesn't support live barcode scanning. Enter a barcode manually instead.")
                    )
                    .safeAreaInset(edge: .bottom) {
                        Button("Enter Barcode Manually") { showManualEntry = true }
                            .buttonStyle(.borderedProminent)
                            .tint(.solaceVitality)
                            .padding()
                    }
                }
            }
            .navigationTitle("Scan")
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
                TextField("Barcode (EAN-13, EAN-8, UPC-E)", text: $manualBarcode)
                    .keyboardType(.numberPad)
            }
            .navigationTitle("Enter Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showManualEntry = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Look Up") {
                        scannedBarcode = manualBarcode
                        showManualEntry = false
                        manualBarcode = ""
                    }
                    .disabled(manualBarcode.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    ScanView()
}
