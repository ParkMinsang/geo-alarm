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


// ContentView.swift

struct ContentView: View {
    @State private var isAddingLocation = false

    var body: some View {
        ZStack {
            MapViewControllerRepresentable()
                .ignoresSafeArea()

            // 버튼들을 담을 컨테이너
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    
                    // ✅ [추가됨] 테스트 버튼
                    Button(action: {
                        // "testAlarm" 신호 보내기
                        NotificationCenter.default.post(name: .didTapTestAlarm, object: nil)
                    }) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.green) // 테스트 버튼은 초록색으로
                            .clipShape(Circle())
                            .shadow(radius: 5)
                    }

                    // 기존 + 버튼
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
                    .padding([.trailing, .bottom]) // 오른쪽, 아래 여백
                }
            }
        }
        .sheet(isPresented: $isAddingLocation) {
            AddLocationView()
        }
    }
}

// Notification 이름 추가
extension Notification.Name {
    static let didAddRegion = Notification.Name("didAddRegion")
    static let didTapTestAlarm = Notification.Name("didTapTestAlarm") // ✅ 테스트용 이름 추가
}
