import envoy
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/http
import gleam/json
import gleam/option.{type Option, Some, unwrap}
import gleam/result
import gleam/time/calendar
import gleam/time/timestamp
import mist
import pog
import sql
import wisp.{type Request, type Response}
import wisp/wisp_mist
import youid/uuid

pub type User {
  User(
    id: uuid.Uuid,
    display_name: String,
    username: String,
    joined: timestamp.Timestamp,
    bio: Option(String),
  )
}

fn user_to_json(user: User) {
  json.object([
    #("id", json.string(uuid.to_string(user.id))),
    #("display_name", json.string(user.display_name)),
    #("username", json.string(user.username)),
    #("joined", timestamp_to_json(user.joined)),
    #("bio", json.string(option.unwrap(user.bio, ""))),
  ])
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

fn timestamp_to_json(ts: timestamp.Timestamp) {
  json.string(timestamp.to_rfc3339(ts, calendar.utc_offset))
}

fn user_handler(req: Request, id: String) {
  case req.method {
    http.Get -> get_user_handler(id)
    http.Delete -> delete_user_handler(id)
    _ -> wisp.method_not_allowed([http.Get, http.Delete])
  }
}

fn delete_user_handler(_id) {
  wisp.no_content()
}

fn get_user_handler(id) {
  wisp.string_body(wisp.ok(), "ID: " <> id)
}

fn users_handler(req: Request) {
  case req.method {
    http.Get -> get_users_handler()
    http.Post -> post_users_handler(req)
    _ -> wisp.method_not_allowed([http.Get, http.Post])
  }
}

fn get_users_handler() {
  let users = [
    User(
      id: uuid.v4(),
      display_name: "Bob Jones",
      username: "bobjones225",
      joined: timestamp.from_unix_seconds(1_766_689_000),
      bio: Some("Some random guy."),
    ),
    User(
      id: uuid.v4(),
      display_name: "Other User",
      username: "otheruser",
      joined: timestamp.from_unix_seconds(1_766_659_000),
      bio: Some("Another random guy."),
    ),
  ]

  json.array(users, user_to_json)
  |> json.to_string
  |> wisp.json_response(200)
}

fn post_users_handler(req: Request) {
  use json <- wisp.require_json(req)

  let result = {
    let decoder = {
      use display_name <- decode.field("display_name", decode.string)
      use username <- decode.field("username", decode.string)
      use bio <- decode.optional_field("bio", "", decode.string)
      decode.success(#(display_name, username, bio))
    }
    use #(display_name, username, bio) <- result.try(decode.run(json, decoder))

    let user =
      User(
        id: uuid.v4(),
        username: username,
        display_name: display_name,
        joined: timestamp.from_unix_seconds(1_766_689_000),
        bio: Some(bio),
      )

    Ok(
      user_to_json(user)
      |> json.to_string
      |> wisp.json_response(200),
    )
  }

  case result {
    Ok(resp) -> resp
    Error(_) -> wisp.unprocessable_content()
  }
}

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

  let db_pool_name = process.new_name("db_pool")
  let assert Ok(database_url) = envoy.get("DATABASE_URL")
  let assert Ok(pog_config) = pog.url_config(db_pool_name, database_url)
  let assert Ok(_) =
    pog_config
    |> pog.pool_size(10)
    |> pog.start

  let con = pog.named_connection(db_pool_name)

  case sql.find_users(con) {
    Ok(users) -> {
      echo "Got todo items"
      echo users
      echo "OK"
    }
    Error(_) -> {
      echo "Failed to get todo items"
    }
  }

  let secret =
    result.unwrap(envoy.get("SECRET_KEY_BASE"), "wisp_secret_fallback")

  let assert Ok(_) =
    wisp_mist.handler(handler, secret)
    |> mist.new
    |> mist.port(8080)
    |> mist.start

  process.sleep_forever()
}
