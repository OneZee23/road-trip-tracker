import Foundation
import SwiftUI
import MapKit
import Combine
import QuartzCore

/// Менеджер плавной анимации трека
class SmoothTrackManager: ObservableObject {
    // Подтверждённые точки трека
    @Published private(set) var confirmedPoints: [CLLocationCoordinate2D] = [] {
        didSet {
            updateSmoothPoints()
        }
    }
    
    // Анимированная "голова" линии
    @Published private(set) var animatedHeadPosition: CLLocationCoordinate2D? {
        didSet {
            // Обновляем сглаженные точки при изменении анимированной позиции
            // Это происходит часто (60-120 FPS), но нужно для плавности
            updateSmoothPoints()
        }
    }
    
    // Сглаженные точки для отображения (публичное для SwiftUI)
    @Published private(set) var smoothDisplayPoints: [CLLocationCoordinate2D] = []
    
    // Точки для отображения
    private var displayPoints: [CLLocationCoordinate2D] {
        var points = confirmedPoints
        if let head = animatedHeadPosition {
            points.append(head)
        }
        return points
    }
    
    // Обновление сглаженных точек
    // @Published гарантирует, что обновления будут на главном потоке
    private func updateSmoothPoints() {
        let points = displayPoints
        if points.count >= 2 {
            smoothDisplayPoints = PathSmoother.smooth(points: points, segmentsPerPoint: 5)
        } else {
            smoothDisplayPoints = points
        }
    }
    
    // Анимация
    private var displayLink: CADisplayLink?
    private var targetPosition: CLLocationCoordinate2D?
    private var animationStartPosition: CLLocationCoordinate2D?
    private var animationStartTime: Date?
    private let animationDuration: TimeInterval = 0.15 // Быстрая анимация для плавности
    
    func startAnimation() {
        displayLink = CADisplayLink(target: self, selector: #selector(animationTick))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        displayLink?.add(to: .main, forMode: .common)
    }
    
    func stopAnimation() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    func reset() {
        confirmedPoints = []
        animatedHeadPosition = nil
        targetPosition = nil
        smoothDisplayPoints = []
    }
    
    /// Добавить новую точку (вызывается при обновлении позиции)
    func addPoint(_ coordinate: CLLocationCoordinate2D) {
        // Если это первая точка
        if confirmedPoints.isEmpty {
            confirmedPoints.append(coordinate)
            animatedHeadPosition = coordinate
            // updateSmoothPoints() вызовется автоматически через didSet
            return
        }
        
        // Подтверждаем предыдущую анимированную позицию
        if let currentHead = animatedHeadPosition {
            let distanceFromLast = distance(from: confirmedPoints.last!, to: currentHead)
            if distanceFromLast > 1 { // > 1 метра
                confirmedPoints.append(currentHead)
                // updateSmoothPoints() вызовется автоматически через didSet
            }
        }
        
        // Начинаем анимацию к новой точке
        animationStartPosition = animatedHeadPosition ?? coordinate
        targetPosition = coordinate
        animationStartTime = Date()
        // animatedHeadPosition будет обновляться в animationTick, что вызовет updateSmoothPoints
    }
    
    @objc private func animationTick() {
        guard let target = targetPosition,
              let startPos = animationStartPosition,
              let startTime = animationStartTime else {
            return
        }
        
        let elapsed = -startTime.timeIntervalSinceNow
        let progress = min(elapsed / animationDuration, 1.0)
        let easedProgress = easeOutQuad(progress)
        
        // Обновляем анимированную позицию (это автоматически вызовет updateSmoothPoints через didSet)
        animatedHeadPosition = CLLocationCoordinate2D(
            latitude: startPos.latitude + (target.latitude - startPos.latitude) * easedProgress,
            longitude: startPos.longitude + (target.longitude - startPos.longitude) * easedProgress
        )
        
        // Анимация завершена
        if progress >= 1.0 {
            animationStartTime = nil
        }
    }
    
    private func easeOutQuad(_ t: Double) -> Double {
        1 - (1 - t) * (1 - t)
    }
    
    private func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let loc1 = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let loc2 = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return loc1.distance(from: loc2)
    }
}
