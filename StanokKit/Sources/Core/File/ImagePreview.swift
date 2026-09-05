import Foundation

// Почему: у картинки в ревью две версии, и обе нужны рядом, а не одна поверх другой
struct ImagePreview: Sendable, Equatable {

    var hasBoth: Bool {
        new != nil && old != nil
    }

    let new: Data?
    let old: Data?
}
