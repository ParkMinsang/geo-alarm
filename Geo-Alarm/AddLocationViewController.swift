// AddLocationViewController.swift

import UIKit
import MapKit

class AddLocationViewController: UIViewController, MKMapViewDelegate {

    // 클로저를 사용하여 이전 화면과 통신 (Delegate 대신)
    var onSave: ((CLCircularRegion) -> Void)?
    var onCancel: (() -> Void)?
    
    let mapView = MKMapView()
    let centerImageView = UIImageView(image: UIImage(systemName: "plus.circle.fill"))
    let radiusLabel = UILabel()
    let radiusSlider = UISlider()
    var circleOverlay: MKCircle?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupMapView()
    }

    func setupUI() {
        title = "지역 추가"
        view.backgroundColor = .systemBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "취소", style: .plain, target: self, action: #selector(cancelTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "저장", style: .done, target: self, action: #selector(saveTapped))
        
        // 지도, 중앙 이미지, 레이블, 슬라이더 UI 설정
        view.addSubview(mapView)
        mapView.translatesAutoresizingMaskIntoConstraints = false

        centerImageView.tintColor = .systemBlue
        centerImageView.contentMode = .scaleAspectFit
        view.addSubview(centerImageView)
        centerImageView.translatesAutoresizingMaskIntoConstraints = false
        
        radiusLabel.text = "반경: 500 m"
        radiusLabel.textAlignment = .center
        
        radiusSlider.minimumValue = 100 // 최소 반경 100m
        radiusSlider.maximumValue = 2000 // 최대 반경 2km
        radiusSlider.value = 500 // 기본값 500m
        radiusSlider.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)

        let controlStackView = UIStackView(arrangedSubviews: [radiusLabel, radiusSlider])
        controlStackView.axis = .vertical
        controlStackView.spacing = 8
        controlStackView.backgroundColor = .systemBackground.withAlphaComponent(0.8)
        controlStackView.layer.cornerRadius = 10
        controlStackView.isLayoutMarginsRelativeArrangement = true
        controlStackView.layoutMargins = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        view.addSubview(controlStackView)
        controlStackView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            centerImageView.centerXAnchor.constraint(equalTo: mapView.centerXAnchor),
            centerImageView.centerYAnchor.constraint(equalTo: mapView.centerYAnchor),
            centerImageView.widthAnchor.constraint(equalToConstant: 44),
            centerImageView.heightAnchor.constraint(equalToConstant: 44),
            
            controlStackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            controlStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            controlStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])
    }

    func setupMapView() {
        mapView.delegate = self
        mapView.showsUserLocation = true
        let initialRegion = MKCoordinateRegion(center: locationManager.location?.coordinate ?? CLLocationCoordinate2D(latitude: 37.5666791, longitude: 126.9782914), latitudinalMeters: 2000, longitudinalMeters: 2000)
        mapView.setRegion(initialRegion, animated: true)
        updateCircleOverlay()
    }

    @objc func cancelTapped() {
        onCancel?()
    }

    @objc func saveTapped() {
        let region = CLCircularRegion(center: mapView.centerCoordinate, radius: CLLocationDistance(radiusSlider.value), identifier: UUID().uuidString)
        onSave?(region)
    }
    
    @objc func sliderValueChanged(_ sender: UISlider) {
        updateCircleOverlay()
    }

    func updateCircleOverlay() {
        if let existingOverlay = circleOverlay {
            mapView.removeOverlay(existingOverlay)
        }
        
        let radius = CLLocationDistance(radiusSlider.value)
        let newCircle = MKCircle(center: mapView.centerCoordinate, radius: radius)
        self.circleOverlay = newCircle
        mapView.addOverlay(newCircle)
        
        radiusLabel.text = String(format: "반경: %.0f m", radius)
    }

    // 지도 이동 시에는 원의 위치만 바뀌도록 하고, 크기는 슬라이더로만 조절
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        updateCircleOverlay()
    }

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
    
    // 다른 파일의 locationManager에 접근하기 위한 편의 속성
    private var locationManager: CLLocationManager {
        // 실제 앱에서는 의존성 주입 등 더 나은 방법을 사용하는 것이 좋습니다.
        // 여기서는 편의를 위해 새로 인스턴스를 생성합니다.
        return CLLocationManager()
    }
}
