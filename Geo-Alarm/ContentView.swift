// ContentView.swift

import SwiftUI

// AddLocationViewController를 SwiftUI의 sheet에서 사용하기 위한 래퍼
struct AddLocationView: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode

    func makeUIViewController(context: Context) -> UINavigationController {
        let addLocationVC = AddLocationViewController()
        
        // "저장" 시 Notification을 보내도록 설정
        addLocationVC.onSave = { region in
            NotificationCenter.default.post(name: .didAddRegion, object: nil, userInfo: ["region": region])
            presentationMode.wrappedValue.dismiss()
        }
        
        // "취소" 시 화면이 닫히도록 설정
        addLocationVC.onCancel = {
            presentationMode.wrappedValue.dismiss()
        }
        
        return UINavigationController(rootViewController: addLocationVC)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
}


struct ContentView: View {
    @State private var isAddingLocation = false

    var body: some View {
        ZStack {
            // 지도 뷰 (배경)
            MapViewControllerRepresentable()
                .ignoresSafeArea() // 안전 영역까지 지도를 꽉 채움

            // + 버튼 (오버레이)
            VStack {
                Spacer() // 버튼을 아래로 밀어냄
                HStack {
                    Spacer() // 버튼을 오른쪽으로 밀어냄
                    Button(action: {
                        isAddingLocation = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(radius: 5)
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $isAddingLocation) {
            AddLocationView()
        }
    }
}

// Notification 이름을 확장하여 오타 방지
extension Notification.Name {
    static let didAddRegion = Notification.Name("didAddRegion")
}
