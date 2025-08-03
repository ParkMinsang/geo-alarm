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
        setupNotification()
        setupTapGestureRecognizer()
        
        // "didAddRegion" 신호를 받을 수 있도록 Observer 등록
        NotificationCenter.default.addObserver(self, selector: #selector(handleNewRegion(notification:)), name: .didAddRegion, object: nil)
    }

    deinit {
        // 뷰 컨트롤러가 메모리에서 해제될 때 Observer를 반드시 제거해야 합니다.
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - 초기 설정

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
    
    func setupTapGestureRecognizer() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(gesture:)))
        mapView.addGestureRecognizer(tapGesture)
    }

    func setupNotification() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - 지역 추가 및 삭제

    @objc func handleNewRegion(notification: Notification) {
        if let region = notification.userInfo?["region"] as? CLCircularRegion {
            addGeofence(for: region)
        }
    }
    
    func addGeofence(for region: CLCircularRegion) {
        region.notifyOnEntry = true
        region.notifyOnExit = false
        
        locationManager.startMonitoring(for: region)

        let circle = MKCircle(center: region.center, radius: region.radius)
        mapView.addOverlay(circle)
    }

    @objc func handleTap(gesture: UITapGestureRecognizer) {
        let touchPoint = gesture.location(in: mapView)
        let coordinate = mapView.convert(touchPoint, toCoordinateFrom: mapView)
        
        // 탭한 위치에 있는 오버레이(원) 찾기
        for overlay in mapView.overlays {
            if let circleOverlay = overlay as? MKCircle {
                let centerLocation = CLLocation(latitude: circleOverlay.coordinate.latitude, longitude: circleOverlay.coordinate.longitude)
                let touchLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                
                if centerLocation.distance(from: touchLocation) <= circleOverlay.radius {
                    // 삭제 확인 팝업
                    let alert = UIAlertController(title: "지역 삭제", message: "이 지역을 삭제하시겠습니까?", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "취소", style: .cancel))
                    alert.addAction(UIAlertAction(title: "삭제", style: .destructive, handler: { _ in
                        self.removeGeofence(for: circleOverlay)
                    }))
                    present(alert, animated: true)
                    return // 첫 번째로 찾은 원만 처리
                }
            }
        }
    }
    
    func removeGeofence(for overlay: MKCircle) {
        // 모니터링 중인 지역에서 해당 지역 찾아서 중지
        for region in locationManager.monitoredRegions {
            if let circularRegion = region as? CLCircularRegion,
               circularRegion.center.latitude == overlay.coordinate.latitude,
               circularRegion.center.longitude == overlay.coordinate.longitude,
               circularRegion.radius == overlay.radius {
                locationManager.stopMonitoring(for: circularRegion)
                break
            }
        }
        // 지도에서 오버레이 삭제
        mapView.removeOverlay(overlay)
    }

    // MARK: - CLLocationManagerDelegate (위치 서비스 관련)

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
        UNUserNotificationCenter.current().add(request)
        
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
        // 알람 소리로 사용할 mp3 파일을 프로젝트에 추가해야 합니다. (예: alarm.mp3)
        guard let url = Bundle.main.url(forResource: "alarm", withExtension: "mp3") else {
            // 파일이 없으면 기본 시스템 사운드 재생
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
        let soundID: SystemSoundID = 1157
        var playingTime: TimeInterval = 0
        
        let completionBlock: AudioServicesSystemSoundCompletionProc = { _,_ in }
        AudioServicesAddSystemSoundCompletion(soundID, nil, nil, completionBlock, nil)
        
        let startTime = Date()
        AudioServicesPlaySystemSoundWithCompletion(soundID) {
            playingTime = Date().timeIntervalSince(startTime)
            completion(playingTime < 0.1)
        }
    }

    // MARK: - MKMapViewDelegate (지도 UI 관련)

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let circleOverlay = overlay as? MKCircle {
            let circleRenderer = MKCircleRenderer(overlay: circleOverlay)
            circleRenderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.2)
            circleRenderer.strokeColor = .systemBlue
            circleRenderer.lineWidth = 1.5
            return circleRenderer
        }
        return MKOverlayRenderer()
    }
}
