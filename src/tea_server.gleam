import envoy
import gleam/erlang/process
import gleam/http
import gleam/io
import gleam/option.{type Option, Some, unwrap}
import gleam/result
import mist
import wisp.{type Request, type Response}
import wisp/wisp_mist
import youid/uuid

pub type User {
  User(
    id: uuid.Uuid,
    display_name: String,
    username: String,
    bio: Option(String),
  )
}

pub fn user_to_string(user: User) -> String {
  "User: "
  <> user.display_name
  <> " (@"
  <> user.username
  <> " ID: "
  <> uuid.to_string(user.id)
  <> " Bio: "
  <> unwrap(user.bio, "")
}

fn user_handler(req, id) {
  case req.method {
    http.Get -> get_user_handler(id)
    http.Delete -> delete_user_handler(id)
    _ -> wisp.method_not_allowed([http.Get, http.Delete])
  }
}

fn delete_user_handler(id) {
  wisp.no_content()
}

fn get_user_handler(req) {
  wisp.string_body(wisp.ok(), "ID")
}

fn users_handler(req: Request) {
  case req.method {
    http.Get -> get_users_hander()
    http.Post -> post_users_hander()
    _ -> wisp.method_not_allowed([http.Get, http.Post])
  }
}

fn get_users_handler()

fn handler(req: Request) -> Response {
  use req <- middleware(req)

  case wisp.path_segments(req) {
    ["users"] -> users_handler(req)
    ["users", id] -> user_handler(req, id)
    _ -> wisp.not_found()
  }
}

fn middleware(req: Request, handler: fn(Request) -> Response) -> Response {
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)
  use req <- wisp.csrf_known_header_protection(req)

  handler(req)
}

pub fn main() -> Nil {
  wisp.configure_logger()

  let secret =
    result.unwrap(envoy.get("SECRET_KEY_BASE"), "wisp_secret_fallback")

  let assert Ok(_) =
    wisp_mist.handler(handler, secret)
    |> mist.new
    |> mist.port(8080)
    |> mist.start

  process.sleep_forever()
}
