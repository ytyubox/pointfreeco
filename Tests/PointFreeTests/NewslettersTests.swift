import EmailAddress
@testable import GitHub
import Html
import HtmlSnapshotTesting
import Models
import ModelsTestSupport
import SnapshotTesting
import Prelude
import XCTest
@testable import PointFree
import PointFreePrelude
import PointFreeRouter
import PointFreeTestSupport
@testable import HttpPipeline
import HttpPipelineTestSupport

class NewslettersIntegrationTests: LiveDatabaseTestCase {
  override func setUp() {
    super.setUp()
//    SnapshotTesting.isRecording = true
  }

  func testExpressUnsubscribe() {
    let user = Current.database.registerUser(withGitHubEnvelope: .mock, email: "hello@pointfree.co", now: { .mock })
      .run
      .perform()
      .right!!

    let payload = expressUnsubscribeIso
      .unapply((user.id, .announcements))
      .flatMap({ Encrypted($0, with: Current.envVars.appSecret) })

    let unsubscribe = request(
      to: .expressUnsubscribe(payload: payload!),
      session: .loggedIn
    )

    assertSnapshot(
      matching: Current.database.fetchEmailSettingsForUserId(user.id)
        .run
        .perform()
        .right!,
      as: .customDump,
      named: "email_settings_before_unsubscribe"
    )

    let output = connection(from: unsubscribe)
      |> siteMiddleware
      |> Prelude.perform
    assertSnapshot(matching: output, as: .conn)

    assertSnapshot(
      matching: Current.database.fetchEmailSettingsForUserId(user.id)
        .run
        .perform()
        .right!,
      as: .customDump,
      named: "email_settings_after_unsubscribe"
    )
  }

  func testExpressUnsubscribeReply() {
    #if !os(Linux)
    let user = Current.database.registerUser(withGitHubEnvelope: .mock, email: "hello@pointfree.co", now: { .mock })
      .run
      .perform()
      .right!!

    let unsubEmail = Current.mailgun.unsubscribeEmail(fromUserId: user.id, andNewsletter: .announcements)!

    let unsubscribe = request(
      to: .expressUnsubscribeReply(
        .init(
          recipient: unsubEmail,
          timestamp: Int(Current.date().timeIntervalSince1970),
          token: "deadbeef",
          sender: user.email,
          signature: "ab77648a3a922e2aab8b0e309e898a6606d071438b6f2490d381c6ca4aa6d8c9"
        )
      ),
      session: .loggedOut
    )

    assertSnapshot(
      matching: Current.database.fetchEmailSettingsForUserId(user.id)
        .run
        .perform()
        .right!,
      as: .customDump,
      named: "email_settings_before_unsubscribe"
    )

    let output = connection(from: unsubscribe)
      |> siteMiddleware
      |> Prelude.perform
    assertSnapshot(matching: output, as: .conn)

    assertSnapshot(
      matching: Current.database.fetchEmailSettingsForUserId(user.id)
        .run
        .perform()
        .right!,
      as: .customDump,
      named: "email_settings_after_unsubscribe"
    )
    #endif
  }

  func testExpressUnsubscribeReply_IncorrectSignature() {
    #if !os(Linux)
    Current.renderHtml = { debugRender($0) }

    let user = Current.database.registerUser(withGitHubEnvelope: .mock, email: "hello@pointfree.co", now: { .mock })
      .run
      .perform()
      .right!!

    let unsubEmail = Current.mailgun.unsubscribeEmail(fromUserId: user.id, andNewsletter: .announcements)!

    let unsubscribe = request(
      to: .expressUnsubscribeReply(
        .init(
          recipient: unsubEmail,
          timestamp: Int(Current.date().timeIntervalSince1970),
          token: "deadbeef",
          sender: user.email,
          signature: "this is an invalid signature"
        )
      ),
      session: .loggedOut
    )

    assertSnapshot(
      matching: Current.database.fetchEmailSettingsForUserId(user.id)
        .run
        .perform()
        .right!,
      as: .customDump,
      named: "email_settings_before_unsubscribe"
    )

    let output = connection(from: unsubscribe)
      |> siteMiddleware
      |> Prelude.perform
    assertSnapshot(matching: output, as: .conn)

    assertSnapshot(
      matching: Current.database.fetchEmailSettingsForUserId(user.id)
        .run
        .perform()
        .right!,
      as: .customDump,
      named: "email_settings_after_unsubscribe"
    )
    #endif
  }

  func testExpressUnsubscribeReply_UnknownNewsletter() {
    #if !os(Linux)
    let user = Current.database.registerUser(withGitHubEnvelope: .mock, email: "hello@pointfree.co", now: { .mock })
      .run
      .perform()
      .right!!

    let payload = encrypted(
      text: "\(user.id.rawValue.uuidString)--unknown",
      secret: Current.envVars.appSecret.rawValue,
      nonce: [0x30, 0x9D, 0xF8, 0xA2, 0x72, 0xA7, 0x4D, 0x37, 0xB9, 0x02, 0xDF, 0x4F]
    )!
    let unsubEmail = EmailAddress(rawValue: "unsub-\(payload)@pointfree.co")

    let unsubscribe = request(
      to: .expressUnsubscribeReply(
        .init(
          recipient: unsubEmail,
          timestamp: Int(Current.date().timeIntervalSince1970),
          token: "deadbeef",
          sender: user.email,
          signature: "ab77648a3a922e2aab8b0e309e898a6606d071438b6f2490d381c6ca4aa6d8c9"
        )
      ),
      session: .loggedOut
    )

    assertSnapshot(
      matching: Current.database.fetchEmailSettingsForUserId(user.id)
        .run
        .perform()
        .right!,
      as: .customDump,
      named: "email_settings_before_unsubscribe"
    )

    let output = connection(from: unsubscribe)
      |> siteMiddleware
      |> Prelude.perform
    assertSnapshot(matching: output, as: .conn)

    assertSnapshot(
      matching: Current.database.fetchEmailSettingsForUserId(user.id)
        .run
        .perform()
        .right!,
      as: .customDump,
      named: "email_settings_after_unsubscribe"
    )
    #endif
  }
}
