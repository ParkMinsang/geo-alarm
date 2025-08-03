// MapViewControllerRepresentable.swift

import SwiftUI
import UIKit

// SwiftUI에서 MapViewController를 사용할 수 있도록 연결하는 래퍼
struct MapViewControllerRepresentable: UIViewControllerRepresentable {
    
    // SwiftUI 뷰를 만들 때 한 번 호출되어 UIViewController를 생성합니다.
    func makeUIViewController(context: Context) -> MapViewController {
        return MapViewController()
    }
    
    // 뷰의 상태가 변경될 때 호출됩니다. (여기서는 특별히 업데이트할 내용이 없습니다.)
    func updateUIViewController(_ uiViewController: MapViewController, context: Context) {
        // 필요한 경우, SwiftUI의 상태를 ViewController로 전달할 수 있습니다.
    }
}
