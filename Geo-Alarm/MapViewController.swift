import UIKit
import MapKit
import CoreLocation
import AVFoundation
import UserNotifications

class MapViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {

    let mapView = MKMapView()
    let locationManager = CLLocationManager()
    var audioPlayer: AVAudioPlayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupMapView()
        setupLocationManager()
        setupGestureRecognizer()
        setupNotification()
    }

    // MARK: - UI 및 초기 설정

    func setupMapView() {
        view.addSubview(mapView)
        mapView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        mapView.delegate = self
        mapView.showsUserLocation = true
    }

    func setupLocationManager() {
        locationManager.delegate = self
        locationManager.requestAlwaysAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.startUpdatingLocation()
    }

    func setupGestureRecognizer() {
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(gesture:)))
        longPressGesture.minimumPressDuration = 1.0
        mapView.addGestureRecognizer(longPressGesture)
    }
    
    func setupNotification() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("D'oh: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - 지역 추가 및 모니터링

    @objc func handleLongPress(gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            let touchPoint = gesture.location(in: mapView)
            let coordinate = mapView.convert(touchPoint, toCoordinateFrom: mapView)
            
            let alert = UIAlertController(title: "지역 추가", message: "이 위치에 알림을 추가하시겠습니까?", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "취소", style: .cancel))
            alert.addAction(UIAlertAction(title: "추가", style: .default, handler: { _ in
                self.addGeofence(at: coordinate)
            }))
            present(alert, animated: true)
        }
    }

    func addGeofence(at coordinate: CLLocationCoordinate2D) {
        let regionRadius: CLLocationDistance = 100 // 100미터 반경
        let region = CLCircularRegion(center: coordinate, radius: regionRadius, identifier: UUID().uuidString)
        region.notifyOnEntry = true
        region.notifyOnExit = false
        
        locationManager.startMonitoring(for: region)

        let circle = MKCircle(center: coordinate, radius: regionRadius)
        mapView.addOverlay(circle)
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if region is CLCircularRegion {
            handleArrival(region: region)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("Monitoring failed for region with identifier: \(region?.identifier ?? "unknown") - \(error.localizedDescription)")
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location Manager failed with the following error: \(error)")
    }


    // MARK: - 알람 및 알림 처리

    func handleArrival(region: CLRegion) {
        let content = UNMutableNotificationContent()
        content.title = "목적지 도착!"
        content.body = "설정한 지역에 도착했습니다."
        
        // 알람 소리 및 진동 제어
        if isHeadphoneConnected() {
            content.sound = .default
        } else {
            checkSilentMode { isSilent in
                if isSilent {
                    // 무음 모드일 경우 진동만 (기본 알림에 진동 포함)
                } else {
                    content.sound = .default
                }
            }
        }

        let request = UNNotificationRequest(identifier: region.identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error adding notification: \(error.localizedDescription)")
            }
        }

        // 앱이 활성화 상태일 때 직접 알람 재생
        if UIApplication.shared.applicationState == .active {
            playAlarm()
        }
    }
    
    func playAlarm() {
        if isHeadphoneConnected() {
            playSound()
        } else {
            checkSilentMode { isSilent in
                if isSilent {
                    self.vibrate()
                } else {
                    self.playSound()
                }
            }
        }
    }

    func playSound() {
        guard let url = Bundle.main.url(forResource: "alarm", withExtension: "mp3") else {
            // "alarm.mp3" 파일이 프로젝트에 없으면 기본 시스템 사운드 재생
            AudioServicesPlaySystemSound(1315)
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.mp3.rawValue)
            audioPlayer?.play()
        } catch let error {
            print(error.localizedDescription)
        }
    }

    func vibrate() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    // MARK: - 오디오 및 무음 모드 확인

    func isHeadphoneConnected() -> Bool {
        let route = AVAudioSession.sharedInstance().currentRoute
        for description in route.outputs {
            if description.portType == .headphones || description.portType == .bluetoothA2DP {
                return true
            }
        }
        return false
    }
    
    func checkSilentMode(completion: @escaping (Bool) -> Void) {
        // 무음 모드 감지는 직접적인 API가 없어, 짧은 소리를 재생하는데 걸리는 시간으로 우회하여 확인합니다.
        let soundID: SystemSoundID = 1157 // 짧고 조용한 소리
        var playingTime: TimeInterval = 0
        
        let completionBlock: AudioServicesSystemSoundCompletionProc = { _,_ in }
        AudioServicesAddSystemSoundCompletion(soundID, nil, nil, completionBlock, nil)
        
        let startTime = Date()
        AudioServicesPlaySystemSoundWithCompletion(soundID) {
            playingTime = Date().timeIntervalSince(startTime)
            // 0.1초 미만으로 재생이 끝나면 무음 모드로 간주
            completion(playingTime < 0.1)
        }
    }

    // MARK: - MKMapViewDelegate

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let circleOverlay = overlay as? MKCircle {
            let circleRenderer = MKCircleRenderer(overlay: circleOverlay)
            circleRenderer.fillColor = UIColor.blue.withAlphaComponent(0.2)
            circleRenderer.strokeColor = .blue
            circleRenderer.lineWidth = 1
            return circleRenderer
        }
        return MKOverlayRenderer()
    }
}
