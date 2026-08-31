import Foundation

enum GitProcessQueue {

    static let serial = DispatchQueue(label: "ru.alobanov11.Stanok.git", qos: .userInitiated)
}
