import Foundation
import SwiftData

/// One billing occurrence. Captured at the moment of renewal so we can display
/// historical amounts on the Detail screen even after prices change.
@Model
final class RenewalEvent {
    var id: UUID
    var subscriptionId: UUID
    var date: Date
    var amount: Decimal
    var currency: String
    var status: RenewalStatus

    init(
        id: UUID = UUID(),
        subscriptionId: UUID,
        date: Date,
        amount: Decimal,
        currency: String,
        status: RenewalStatus = .scheduled
    ) {
        self.id = id
        self.subscriptionId = subscriptionId
        self.date = date
        self.amount = amount
        self.currency = currency
        self.status = status
    }
}
