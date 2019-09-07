import FunctionalCss
import GitHub
import Html
import HtmlCssSupport
import Optics
import PointFreeRouter
import Prelude
import Styleguide

let registrationEmailView = simpleEmailLayout(registrationEmailBody) <<< { user in
  SimpleEmailLayoutData(
    user: nil,
    newsletter: nil,
    title: "Thanks for signing up!",
    preheader: "",
    template: .default,
    data: user
  )
}

private func registrationEmailBody(user: GitHubUser) -> [Node] {
  return [
    emailTable([style(contentTableStyles)], [
      tr([
        td([valign(.top)], [
          div([`class`([Class.padding([.mobile: [.all: 2]])])], [
            h3([`class`([Class.pf.type.responsiveTitle3])], ["Thanks for signing up!"]),
            p([`class`([Class.padding([.mobile: [.topBottom: 2]])])], [
              "You’re one step closer to our video series!"
              ]),

            p([`class`([Class.padding([.mobile: [.bottom: 2]])])], [
              """
            To get all that Point-Free has to offer, choose from one of our monthly or yearly plans by clicking
            the link below!
            """
              ]),

            p([`class`([Class.padding([.mobile: [.topBottom: 2]])])], [
              a([href(url(to: .pricingLanding)), `class`([Class.pf.components.button(color: .purple)])],
                ["Choose a subscription plan!"])
              ])
            ])
          ])
        ])
      ])
  ]
}
