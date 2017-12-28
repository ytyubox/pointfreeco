import Css
import Either
import Foundation
import Html
import HtmlCssSupport
import HttpPipeline
import HttpPipelineHtmlSupport
import Optics
import Prelude
import Styleguide
import Tuple

private let adminEmails = [
  "mbw234@gmail.com",
  "stephen.celis@gmail.com"
]

func requireAdmin<A>(
  _ middleware: @escaping Middleware<StatusLineOpen, ResponseEnded, T2<Database.User, A>, Data>
  ) -> Middleware<StatusLineOpen, ResponseEnded, T2<Database.User, A>, Data> {

  return { conn in
    conn
      |> (adminEmails.contains(get1(conn.data).email.unwrap) ? middleware : redirect(to: .secretHome))
  }
}

let adminIndex =
  filterMap(require1, or: loginAndRedirect)
    <<< requireAdmin
    <| writeStatus(.ok)
    >-> respond(adminIndexView.contramap(lower))

private let adminIndexView = View<Database.User> { currentUser in
  ul([
    li([
      a([href(path(to: .admin(.newEpisodeEmail(.show))))], ["Send new episode email"])
      ])
    ])
}

let showNewEpisodeEmailMiddleware =
  filterMap(require1, or: loginAndRedirect)
    <<< requireAdmin
    <| writeStatus(.ok)
    >-> respond(showNewEpisodeView.contramap(lower))

private let showNewEpisodeView = View<Database.User> { currentUser in
  ul(
    episodes
      .sorted(by: ^\.sequence)
      .map(li <<< newEpisodeEmailRowView.view)
    )
}

private let newEpisodeEmailRowView = View<Episode> { ep in
  p([
    .text(encode(ep.title)),
    form([action(path(to: .admin(.newEpisodeEmail(.send(ep.id))))), method(.post)], [
      input([type(.submit), value("Send email!")])
      ])
    ])
}

let sendNewEpisodeEmailMiddleware: Middleware<StatusLineOpen, ResponseEnded, T2<Episode.Id, Prelude.Unit>, Data> =
  requireEpisode(notFoundMiddleware: redirect(to: .admin(.newEpisodeEmail(.show))))
    <<< requireUser
    <<< requireAdmin
    <| { conn in pure(conn.map(get2)) }
    >-> sendNewEpisodeEmails
    >-> redirect(to: .admin(.index))

func requireEpisode<A>(
  notFoundMiddleware: @escaping Middleware<StatusLineOpen, ResponseEnded, T2<Episode.Id, A>, Data>
  )
  -> (@escaping Middleware<StatusLineOpen, ResponseEnded, T2<Episode, A>, Data>)
  -> Middleware<StatusLineOpen, ResponseEnded, T2<Episode.Id, A>, Data> {

    return { middleware in
      return { conn in
        guard let episode = episodes.first(where: { $0.id.unwrap == get1(conn.data).unwrap })
          else { return conn |> notFoundMiddleware }

        return conn.map(over1(const(episode)))
          |> middleware
      }
    }
}

private func sendNewEpisodeEmails<I>(_ conn: Conn<I, Episode>) -> IO<Conn<I, Prelude.Unit>> {

  return AppEnvironment.current.database.fetchUsersSubscribedToNewEpisodeEmail()
    .mapExcept(bimap(const(unit), id))
    .flatMap { users in sendEmail(forNewEpisode: conn.data, toUsers: users) }
    .run
    .map { _ in conn.map(const(unit)) }
}

private func sendEmail(forNewEpisode episode: Episode, toUsers users: [Database.User]) -> EitherIO<Prelude.Unit, Prelude.Unit> {

  return lift <| IO {
    // TODO: look into mailgun rate limits. we could batch subscribers and non subscribers at least
    let newEpisodeEmails = users.enumerated().map { idx, user in
      sendEmail(
        to: [user.email],
        subject: "New Point-Free Episode: \(episode.title)",
        content: inj2(newEpisodeEmail.view((episode, true)))
        )
        .delay(.milliseconds(200 * idx))
        .retry(maxRetries: 3, backoff: { .milliseconds(200 * idx) + .seconds(10 * $0) })
    }

    zip(newEpisodeEmails.map(^\.run >>> parallel))
      .sequential
      .flatMap { results in
        sendEmail(
          to: adminEmails.map(EmailAddress.init(unwrap:)),
          subject: "New episode email finished sending!",
          content: inj2(
            newEpisodeEmailAdminReportEmail.view(
              (
                zip(users, results)
                  .filter(second >>> ^\.isLeft)
                  .map(first),

                results.count
              )
            )
          )
          )
          .run
      }
      .parallel
      .run({ _ in })

    return unit
  }
}
