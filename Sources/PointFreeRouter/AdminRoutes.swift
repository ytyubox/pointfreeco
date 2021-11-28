import ApplicativeRouter
import Foundation
import Models
import Prelude
import URLRouting

public enum Admin: Equatable {
  case episodeCredits(EpisodeCredit)
  case freeEpisodeEmail(FreeEpisodeEmail)
  case ghost(Ghost)
  case index
  case newBlogPostEmail(NewBlogPostEmail)
  case newEpisodeEmail(NewEpisodeEmail)

  public enum EpisodeCredit: Equatable {
    case add(userId: User.Id?, episodeSequence: Episode.Sequence?)
    case show
  }

  public enum FreeEpisodeEmail: Equatable {
    case send(Episode.Id)
    case index
  }

  public enum Ghost: Equatable {
    case index
    case start(User.Id?)
  }

  public enum NewBlogPostEmail: Equatable {
    case send(BlogPost.Id, formData: NewBlogPostFormData?, isTest: Bool?)
    case index
  }

  public enum NewEpisodeEmail: Equatable {
    case send(Episode.Id, subscriberAnnouncement: String?, nonSubscriberAnnouncement: String?, isTest: Bool?)
    case show
  }
}

public let adminRouter = adminRouters.reduce(.empty, <|>)

private let adminRouters: [Router<Admin>] = [
  .case { .episodeCredits(.add(userId: $0, episodeSequence: $1)) }
    <¢> post %> "episode-credits" %> "add"
    %> formField("user_id", Optional.iso.some >>> opt(.tagged(.uuid)))
    <%> formField("episode_sequence", Optional.iso.some >>> opt(.tagged(.int)))
    <% end,

  .case(.episodeCredits(.show))
    <¢> get %> "episode-credits" %> end,

  .case(.index)
    <¢> get <% end,

  .case { .freeEpisodeEmail(.send($0)) }
    <¢> post %> "free-episode-email" %> pathParam(.tagged(.int)) <% "send" <% end,

  .case(.freeEpisodeEmail(.index))
    <¢> get %> "free-episode-email" <% end,

  .case(.ghost(.index))
    <¢> get %> "ghost" <% end,

  .case { .ghost(.start($0)) }
    <¢> post %> "ghost" %> "start"
    %> formField("user_id", .tagged(.uuid)).map(Optional.iso.some)
    <% end,

  .case(.newBlogPostEmail(.index))
    <¢> get %> "new-blog-post-email" <% end,

  parenthesize(.case { .newBlogPostEmail(.send($0, formData: $1, isTest: $2)) })
    <¢> post %> "new-blog-post-email" %> pathParam(.tagged(.int)) <%> "send"
    %> formBody(NewBlogPostFormData?.self, decoder: formDecoder)
    <%> isTest
    <% end,

  .case(Admin.newEpisodeEmail) <<< parenthesize(.case(Admin.NewEpisodeEmail.send))
    <¢> post %> "new-episode-email" %> pathParam(.tagged(.int)) <%> "send"
    %> formField("subscriber_announcement", .string).map(Optional.iso.some)
    <%> formField("nonsubscriber_announcement", .string).map(Optional.iso.some)
    <%> isTest
    <% end,

  .case(.newEpisodeEmail(.show))
    <¢> get %> "new-episode-email" <% end,
]

private let _adminRouter = OneOf {
  Routing(/Admin.index) {
    Method.get
  }

  Routing(/Admin.episodeCredits) {
    Path { "episode-credits" }

    OneOf {
      Routing(/Admin.EpisodeCredit.show) {
        Method.get
      }

      Routing(/Admin.EpisodeCredit.add(userId:episodeSequence:)) {
        Method.post
        Body {
          FormData {
            Field("user_id", UUID.parser().pipe { User.Id.parser() })
            Field("episode_sequence", Int.parser().pipe { Episode.Sequence.parser() })
          }
        }
      }
    }
  }

  Routing(/Admin.freeEpisodeEmail) {
    Path { "free-episode-email" }

    OneOf {
      Routing(/Admin.FreeEpisodeEmail.index) {
        Method.get
      }

      Routing(/Admin.FreeEpisodeEmail.send) {
        Method.get
        Path {
          Int.parser().pipe { Episode.Id.parser() }
          "send"
        }
      }
    }
  }

  Routing(/Admin.ghost) {
    Path { "ghost" }

    OneOf {
      Routing(/Admin.Ghost.index) {
        Method.get
      }

      Routing(/Admin.Ghost.start) {
        Method.post
        Path { "start" }
        Body {
          FormData {
            Field("user_id", UUID.parser().pipe { User.Id.parser() })
          }
        }
      }
    }
  }

  Routing(/Admin.newBlogPostEmail) {
    Path { "new-blog-post-email" }

    OneOf {
      Routing(/Admin.NewBlogPostEmail.index) {
        Method.get
      }

      Routing(/Admin.NewBlogPostEmail.send) {
        Parse {
          Path {
            Int.parser().pipe { BlogPost.Id.parser() }
            "send"
          }
          Body {
            FormCoded(NewBlogPostFormData.self, decoder: formDecoder)
            FormData {
              Optionally {
                Field("test", Bool.parser())
              }
            }
          }
        }
        .pipe(
          Conversion(
            apply: { ($0, $1.0, $1.1) },
            unapply: { ($0, ($1, $2)) }
          )
        )
      }
    }
  }

  Routing(/Admin.newEpisodeEmail) {
    Path { "new-episode-email" }

    OneOf {
      Routing(/Admin.NewEpisodeEmail.show) {
        Method.get
      }

      Routing(/Admin.NewEpisodeEmail.send) {
        Parse {
          Path {
            Int.parser().pipe { Episode.Id.parser() }
            "send"
          }
          Body {
            FormData {
              Optionally {
                Field("subscriber_announcement", String.parser())
              }
              Optionally {
                Field("nonsubscriber_announcement", String.parser())
              }
              Optionally {
                Field("test", Bool.parser())
              }
            }
          }
        }
        .pipe(
          Conversion(
            apply: { ($0, $1.0, $1.1, $1.2) },
            unapply: { ($0, ($1, $2, $3)) }
          )
        )
      }
    }
  }
}
