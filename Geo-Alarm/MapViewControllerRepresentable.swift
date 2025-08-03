// MapViewControllerRepresentable.swift

import SwiftUI
import UIKit

struct MapViewControllerRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> MapViewController {
        return MapViewController()
    }
    
    func updateUIViewController(_ uiViewController: MapViewController, context: Context) {
        // 업데이트 로직
    }
}
