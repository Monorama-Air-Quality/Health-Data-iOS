import Foundation
import HealthKit
import CoreLocation

struct UserInfo: Codable {
    let bloodType: String?
    let biologicalSex: String?
    let birthDate: String?
    let latitude: Double?
    let longitude: Double?
}

struct HealthData: Codable {
    let email: String
    let provider: HealthProvider
    let userInfo: UserInfo
    let measurements: Measurements
    let timestamp: Date
    
    enum HealthProvider: String, Codable {
        case samsung
        case apple
        case google
    }
}

struct Measurements: Codable {
    let stepCount: Double?
    let heartRate: Double?
    let bloodPressureSystolic: Double?
    let bloodPressureDiastolic: Double?
    let oxygenSaturation: Double?
    let bodyTemperature: Double?
    let respiratoryRate: Double?
    let height: Double?
    let weight: Double?
    let runningSpeed: Double?
    let activeEnergy: Double?
    let basalEnergy: Double?
}

extension HealthData {
    static func from(healthKitData: [HKSample], userInfo: UserInfo) -> HealthData {
        var measurements = Measurements(
            stepCount: nil,
            heartRate: nil,
            bloodPressureSystolic: nil,
            bloodPressureDiastolic: nil,
            oxygenSaturation: nil,
            bodyTemperature: nil,
            respiratoryRate: nil,
            height: nil,
            weight: nil,
            runningSpeed: nil,
            activeEnergy: nil,
            basalEnergy: nil
        )
        
        for sample in healthKitData {
            guard let quantitySample = sample as? HKQuantitySample else { continue }
            
            let value = quantitySample.quantity.doubleValue(for: getUnit(for: quantitySample.quantityType))
            
            switch quantitySample.quantityType.identifier {
            case HKQuantityTypeIdentifier.stepCount.rawValue:
                measurements = Measurements(stepCount: value, heartRate: measurements.heartRate,
                    bloodPressureSystolic: measurements.bloodPressureSystolic,
                    bloodPressureDiastolic: measurements.bloodPressureDiastolic,
                    oxygenSaturation: measurements.oxygenSaturation,
                    bodyTemperature: measurements.bodyTemperature,
                    respiratoryRate: measurements.respiratoryRate,
                    height: measurements.height,
                    weight: measurements.weight,
                    runningSpeed: measurements.runningSpeed,
                    activeEnergy: measurements.activeEnergy,
                    basalEnergy: measurements.basalEnergy)
            default:
                break
            }
        }
        
        return HealthData(
            email: UserDefaults.standard.string(forKey: "email") ?? "",
            provider: .apple,
            userInfo: userInfo,
            measurements: measurements,
            timestamp: Date()
        )
    }
    
    private static func getUnit(for quantityType: HKQuantityType) -> HKUnit {
        switch quantityType.identifier {
        case HKQuantityTypeIdentifier.stepCount.rawValue:
            return .count()
        case HKQuantityTypeIdentifier.heartRate.rawValue:
            return HKUnit.count().unitDivided(by: .minute())
        case HKQuantityTypeIdentifier.bloodPressureSystolic.rawValue,
             HKQuantityTypeIdentifier.bloodPressureDiastolic.rawValue:
            return .millimeterOfMercury()
        case HKQuantityTypeIdentifier.oxygenSaturation.rawValue:
            return .percent()
        case HKQuantityTypeIdentifier.bodyTemperature.rawValue:
            return .degreeCelsius()
        case HKQuantityTypeIdentifier.respiratoryRate.rawValue:
            return HKUnit.count().unitDivided(by: .minute())
        case HKQuantityTypeIdentifier.height.rawValue:
            return .meterUnit(with: .centi)
        case HKQuantityTypeIdentifier.bodyMass.rawValue:
            return .gramUnit(with: .kilo)
        case HKQuantityTypeIdentifier.runningSpeed.rawValue:
            return HKUnit.meter().unitDivided(by: .second())
        case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue,
             HKQuantityTypeIdentifier.basalEnergyBurned.rawValue:
            return .kilocalorie()
        default:
            return .count()
        }
    }
}