import Either
import Foundation
import HttpPipeline
import Models
import Prelude
import Stripe

let stripePaymentIntentsWebhookMiddleware
  : (Conn<StatusLineOpen, Event<PaymentIntent>>) -> IO<Conn<ResponseEnded, Data>>
  = validateStripeSignature
    <<< validateEvent
    <<< fetchGift
    <| handlePaymentIntent

private func validateEvent(
  _ middleware: @escaping Middleware<StatusLineOpen, ResponseEnded, PaymentIntent, Data>
) -> Middleware<StatusLineOpen, ResponseEnded, Event<PaymentIntent>, Data> {

  return { conn in
    let event = conn.data
    switch event.type {
    case .paymentIntentPaymentFailed:
      // TODO: Email gift giver?
      return conn |> writeStatus(.ok) >=> respond(text: "OK")

    case .paymentIntentSucceeded:
      return conn.map(const(event.data.object)) |> middleware

    default:
      return conn |> stripeHookFailure(
        subject: "[PointFree Error] Stripe Hook Failed!",
        body: "Payment intents hook received unhandled event \(event.type)"
      )
    }
  }
}

private func fetchGift(
  _ middleware: @escaping Middleware<StatusLineOpen, ResponseEnded, (PaymentIntent, Gift), Data>
) -> Middleware<StatusLineOpen, ResponseEnded, PaymentIntent, Data> {

  return { conn in
    let paymentIntent = conn.data
    return Current.database.fetchGiftByStripePaymentIntentId(paymentIntent.id)
      .run
      .flatMap { errorOrGift in
        switch errorOrGift {
        case .left:
          return conn |> writeStatus(.ok) >=> respond(text: "OK")

        case let .right(gift):
          return conn.map(const((paymentIntent, gift))) |> middleware
        }
      }
  }
}

private func handlePaymentIntent(
  conn: Conn<StatusLineOpen, (PaymentIntent, Gift)>
) -> IO<Conn<ResponseEnded, Data>> {
  let (paymentIntent, gift) = conn.data

  guard paymentIntent.status == .succeeded
  else { return conn |> writeStatus(.ok) >=> respond(text: "OK") }

  return Current.database.fetchGiftByStripePaymentIntentId(paymentIntent.id)
    .flatMap { gift in
      gift.deliverAt == nil
      ? sendGiftEmail(for: gift)
        .flatMap(const(Current.database.updateGiftStatus(gift.id, paymentIntent.status, true)))
      : Current.database.updateGiftStatus(gift.id, paymentIntent.status, false)
    }
    .run
    .flatMap {
      switch $0 {
      case let .left(error):
        return conn |> stripeHookFailure(
          subject: "[PointFree Error] Stripe Hook Failed!",
          body: "Failed to deliver gift \(gift.id): \(error)"
        )

      case .right:
        return conn |> writeStatus(.ok) >=> respond(text: "OK")
      }
    }
}
