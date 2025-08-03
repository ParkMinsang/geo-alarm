import UIKit
import MapKit
import CoreLocation
import AVFoundation
import UserNotifications
import CoreHaptics

class MapViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {

    let mapView = MKMapView()
    let locationManager = CLLocationManager()
    var audioPlayer: AVAudioPlayer?

    private var isAlarmingForRegionIdentifier: String?
    private var hapticEngine: CHHapticEngine?
    // ✅ [수정됨] 플레이어 타입을 고급 플레이어로 변경
    private var hapticPlayer: CHHapticAdvancedPatternPlayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupMapView()
        setupLocationManager()
        setupNotification()
        setupTapGestureRecognizer()
        setupHaptics()

        NotificationCenter.default.addObserver(self, selector: #selector(handleNewRegion(notification:)), name: .didAddRegion, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleTestAlarm), name: .didTapTestAlarm, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - 초기 설정
    
    func setupHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            print("이 기기는 CoreHaptics를 지원하지 않습니다.")
            return
        }
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            print("햅틱 엔진 시작 실패: \(error)")
        }
    }

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

    // MARK: - 지역 추가, 삭제, 테스트

    @objc func handleNewRegion(notification: Notification) {
        if let region = notification.userInfo?["region"] as? CLCircularRegion {
            addGeofence(for: region)

            if let currentLocation = locationManager.location, region.contains(currentLocation.coordinate) {
                if isAlarmingForRegionIdentifier == nil {
                    handleArrival(region: region)
                }
            }
        }
    }

    @objc func handleTestAlarm() {
        guard isAlarmingForRegionIdentifier == nil else { return }
        let fakeRegion = CLRegion()
        handleArrival(region: fakeRegion)
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
        
        for overlay in mapView.overlays {
            if let circleOverlay = overlay as? MKCircle {
                let centerLocation = CLLocation(latitude: circleOverlay.coordinate.latitude, longitude: circleOverlay.coordinate.longitude)
                let touchLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                
                if centerLocation.distance(from: touchLocation) <= circleOverlay.radius {
                    let alert = UIAlertController(title: "지역 삭제", message: "이 지역을 삭제하시겠습니까?", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "취소", style: .cancel))
                    alert.addAction(UIAlertAction(title: "삭제", style: .destructive, handler: { _ in
                        self.removeGeofence(for: circleOverlay)
                    }))
                    present(alert, animated: true)
                    return
                }
            }
        }
    }
    
    func removeGeofence(for overlay: MKCircle) {
        for region in locationManager.monitoredRegions {
            if let circularRegion = region as? CLCircularRegion,
               circularRegion.center.latitude == overlay.coordinate.latitude,
               circularRegion.center.longitude == overlay.coordinate.longitude,
               circularRegion.radius == overlay.radius {
                locationManager.stopMonitoring(for: circularRegion)
                break
            }
        }
        mapView.removeOverlay(overlay)
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if isAlarmingForRegionIdentifier == nil {
            handleArrival(region: region)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("Monitoring failed for region: \(region?.identifier ?? "unknown") - \(error.localizedDescription)")
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location Manager failed with error: \(error)")
    }

    // MARK: - 알람 및 알림 처리

    func handleArrival(region: CLRegion) {
        isAlarmingForRegionIdentifier = region.identifier

        let content = UNMutableNotificationContent()
        content.title = "목적지 도착! 📍"
        content.body = "설정한 지역에 도착했습니다."
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
        
        if UIApplication.shared.applicationState == .active {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                guard self.isAlarmingForRegionIdentifier == region.identifier else { return }
                
                self.playContinuousAlarm()

                let alert = UIAlertController(title: "목적지 도착! 📍", message: "설정한 지역에 도착했습니다.", preferredStyle: .alert)
                let stopAction = UIAlertAction(title: "알람 끄기", style: .default) { _ in
                    self.stopAlarm()
                }
                alert.addAction(stopAction)
                self.present(alert, animated: true)
            }
        }
    }
    
    func stopAlarm() {
        audioPlayer?.stop()
        try? hapticPlayer?.stop(atTime: 0)
        isAlarmingForRegionIdentifier = nil
        
        if self.presentedViewController is UIAlertController {
            self.dismiss(animated: true)
        }
    }

    func playContinuousAlarm() {
        playSound()
        playContinuousVibration()
    }

    func playSound() {
        guard let url = Bundle.main.url(forResource: "alarm", withExtension: "mp3") else {
            AudioServicesPlaySystemSound(1315)
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.mp3.rawValue)
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.play()
        } catch let error {
            print("소리 재생 실패: \(error.localizedDescription)")
        }
    }

    func playContinuousVibration() {
        guard let engine = hapticEngine else { return }

        do {
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
            let continuousEvent = CHHapticEvent(eventType: .hapticContinuous, parameters: [intensity, sharpness], relativeTime: 0, duration: 1.0)
            
            let pattern = try CHHapticPattern(events: [continuousEvent], parameters: [])
            
            // ✅ [수정됨] 고급 플레이어 생성
            hapticPlayer = try engine.makeAdvancedPlayer(with: pattern)
            
            hapticPlayer?.loopEnabled = true
            try hapticPlayer?.start(atTime: 0)
            
        } catch {
            print("햅틱 재생 실패: \(error.localizedDescription)")
        }
    }

    // MARK: - MKMapViewDelegate

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
