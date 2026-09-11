//
//  BarcodeScannerView.swift
//  Solace
//

import SwiftUI
import Vision
import VisionKit

/// Live camera barcode scanner (Section 9). Requires `NSCameraUsageDescription`,
/// already set in the target's Info.plist build settings.
struct BarcodeScannerView: UIViewControllerRepresentable {
    /// Pauses live detection once a barcode's been captured (e.g. while its
    /// Product Detail screen is showing), instead of continuing to scan in
    /// the background and re-firing `onScan` for whatever's still in frame.
    var isScanning: Bool
    var onScan: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce])],
            qualityLevel: .accurate,
            recognizesMultipleItems: false,
            isHighlightingEnabled: true
        )
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: DataScannerViewController, context: Context) {
        if isScanning {
            try? vc.startScanning()
        } else {
            vc.stopScanning()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        init(onScan: @escaping (String) -> Void) { self.onScan = onScan }

        func dataScanner(_ scanner: DataScannerViewController, didAdd items: [RecognizedItem], allItems: [RecognizedItem]) {
            for case .barcode(let barcode) in items {
                if let payload = barcode.payloadStringValue {
                    onScan(payload)
                }
            }
        }
    }
}

/// Availability gate: `DataScannerViewController` requires camera hardware
/// the Simulator doesn't have, and users can deny camera access.
enum BarcodeScannerAvailability {
    static var isSupported: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }
}
