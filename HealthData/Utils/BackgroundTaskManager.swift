import UIKit

class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var isRunning = false
    private var nextCollectionWorkItem: DispatchWorkItem?
    
    // 기기 잠금 상태 추적
    private var isDeviceLocked = false
    
    private init() {
        // 앱이 백그라운드로 전환될 때 알림 받기
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        // 앱이 비활성화될 때 (잠금화면으로 전환될 때)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceDidLock),
            name: UIApplication.protectedDataWillBecomeUnavailableNotification,
            object: nil
        )
        
        // 앱이 활성화될 때 (잠금해제될 때)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceDidUnlock),
            name: UIApplication.protectedDataDidBecomeAvailableNotification,
            object: nil
        )
    }
    
    // 기기가 잠금 상태가 되었을 때
    @objc private func deviceDidLock() {
        print("🔒 기기 잠금 상태 감지됨: \(Date())")
        isDeviceLocked = true
        // 실행 중인 작업 취소
        nextCollectionWorkItem?.cancel()
        nextCollectionWorkItem = nil
        endBackgroundTask()
    }
    
    // 실제 기기 잠금이 해제되었을 때
    @objc private func deviceDidUnlock() {
        print("🔓 기기 잠금 해제됨: \(Date())")
        isDeviceLocked = false
        // 잠금 해제되고 실행 중이면 데이터 수집 재시작
        if isRunning {
            scheduleNextCollection()
        }
    }
    
    func startBackgroundTaskWithDelay() {
        print("\n🚀 백그라운드 작업 시작: \(Date())")
        isRunning = true
        
        // 기기가 잠금 상태가 아닐 때만 다음 수집 예약
        if !isDeviceLocked {
            scheduleNextCollection(afterDelay: 60)
            print("⏰ 1분 후 첫 실행 예정: \(Date(timeIntervalSinceNow: 60))")
        } else {
            print("🔒 기기가 잠금 상태여서 데이터 수집을 시작하지 않습니다.")
        }
    }
    
    private func scheduleNextCollection(afterDelay: TimeInterval = 60) {
        guard isRunning && !isDeviceLocked else { 
            print("⏸ 데이터 수집 예약 취소: 실행 중지 또는 기기 잠금 상태")
            return 
        }
        
        // 이전 예약된 작업 취소
        nextCollectionWorkItem?.cancel()
        
        // 새로운 작업 생성
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self, !self.isDeviceLocked else { return }
            
            // 새로운 백그라운드 작업 시작
            self.backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
                print("⚠️ 백그라운드 작업 시간 만료: \(Date())")
                self?.endBackgroundTask()
            }
            
            // 데이터 수집 및 전송
            Task {
                await self.startNewDataCollection()
                self.endBackgroundTask()
                
                // 다음 수집 예약 (기기가 잠금 상태가 아닐 때만)
                if !self.isDeviceLocked {
                    self.scheduleNextCollection()
                }
            }
        }
        
        nextCollectionWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + afterDelay, execute: workItem)
    }
    
    @objc private func applicationDidEnterBackground() {
        print("📱 앱이 백그라운드로 전환됨: \(Date())")
        // 백그라운드에서도 데이터 수집 계속 진행
        if isRunning {
            scheduleNextCollection()
        }
    }
    
    private func startNewDataCollection() async {
        print("\n🔄 새로운 데이터 수집 시작: \(Date())")
        
        do {
            let projectId = UserDefaults.standard.integer(forKey: "lastProjectId")
            guard projectId != 0 else {
                print("❌ 프로젝트 ID가 없음")
                return
            }
            
            let startTime = Date()
            print("📱 데이터 수집 시작: \(startTime)")
            
            // 헬스 데이터 가져오기
            let healthData = try await HealthKitManager.shared.fetchAllHealthData(projectId: projectId)
            
            // JSON 로깅
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            if let jsonData = try? encoder.encode(healthData),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                print("\n📤 전송할 데이터:")
                print(jsonString)
            }
            
            // 서버로 전송
            try await APIService.shared.registerHealthData(healthData, projectId: projectId)
            
            let endTime = Date()
            print("✅ 데이터 전송 성공: \(endTime)")
            print("⏱ 전송 소요 시간: \(endTime.timeIntervalSince(startTime))초")
            
        } catch {
            print("❌ 데이터 전송 실패: \(error.localizedDescription)")
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    deinit {
        nextCollectionWorkItem?.cancel()
        NotificationCenter.default.removeObserver(self)
        endBackgroundTask()
    }
}
