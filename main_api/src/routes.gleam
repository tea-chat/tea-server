import context
import user_auth as auth
import users
import wisp.{type Request, type Response}

pub fn handler(req: Request, ctx: context.Context) -> Response {
  use req <- middleware(req)

  case wisp.path_segments(req) {
    ["users"] -> users.users_handler(req, ctx)
    ["users", id] -> users.user_handler(req, ctx, id)
    ["me"] -> users.me_handler(req, ctx)
    ["login"] -> auth.login_handler(req, ctx)
    _ -> wisp.not_found()
  }
}

pub fn middleware(req: Request, handler: fn(Request) -> Response) -> Response {
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)
  use req <- wisp.csrf_known_header_protection(req)

  handler(req)
}
