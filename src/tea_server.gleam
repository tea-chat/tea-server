import envoy
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/http
import gleam/io
import gleam/json
import gleam/list
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

pub type Context {
  Context(db: pog.Connection)
}

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
  <> ")"
}

fn timestamp_to_json(ts: timestamp.Timestamp) {
  json.string(timestamp.to_rfc3339(ts, calendar.utc_offset))
}

fn user_handler(req: Request, ctx: Context, id: String) {
  case req.method {
    http.Get -> get_user_handler(ctx, id)
    http.Delete -> delete_user_handler(ctx, id)
    _ -> wisp.method_not_allowed([http.Get, http.Delete])
  }
}

fn delete_user_handler(ctx: Context, id: String) {
  case uuid.from_string(id) {
    Ok(id) -> {
      case sql.delete_user(ctx.db, id) {
        Ok(_) -> wisp.no_content()
        Error(_) -> wisp.internal_server_error()
      }
    }
    Error(_) -> wisp.bad_request("Invalid id")
  }
}

fn get_user_handler(ctx: Context, id: String) {
  case uuid.from_string(id) {
    Ok(id) -> {
      case sql.find_user(ctx.db, id) {
        Ok(user) -> {
          case user.rows {
            [] -> wisp.not_found()
            [row] -> {
              let user =
                User(
                  row.id,
                  row.display_name,
                  row.username,
                  row.joined,
                  row.bio,
                )

              user_to_json(user)
              |> json.to_string
              |> wisp.json_response(200)
            }
            _ -> {
              wisp.internal_server_error()
            }
          }
        }
        Error(_) -> wisp.internal_server_error()
      }
    }
    Error(_) -> wisp.bad_request("Invalid id")
  }
}

fn users_handler(req: Request, ctx: Context) {
  case req.method {
    http.Get -> get_users_handler(ctx)
    http.Post -> post_users_handler(req, ctx)
    _ -> wisp.method_not_allowed([http.Get, http.Post])
  }
}

fn get_users_handler(ctx: Context) {
  case sql.find_users(ctx.db) {
    Ok(todo_items) -> {
      todo_items.rows
      |> list.map(fn(row: sql.FindUsersRow) {
        User(row.id, row.display_name, row.username, row.joined, row.bio)
      })
      |> json.array(user_to_json)
      |> json.to_string
      |> wisp.json_response(200)
    }
    Error(_) -> {
      wisp.internal_server_error()
    }
  }
}

fn post_users_handler(req: Request, ctx: Context) {
  use json <- wisp.require_json(req)

  let result = {
    let decoder = {
      use username <- decode.field("username", decode.string)
      use display_name <- decode.field("display_name", decode.string)
      use bio <- decode.optional_field("bio", "", decode.string)
      decode.success(#(username, display_name, bio))
    }
    use #(username, display_name, bio) <- result.try(decode.run(json, decoder))

    case sql.insert_user(ctx.db, username, display_name, bio) {
      Ok(r) -> {
        case r.rows {
          [row] -> {
            let user =
              User(row.id, row.display_name, row.username, row.joined, row.bio)

            wisp.log_info("User Created! " <> user_to_string(user))

            user
            |> user_to_json()
            |> json.to_string
            |> wisp.json_response(200)
            |> Ok()
          }
          _ -> Ok(wisp.internal_server_error())
        }
      }
      Error(_) -> {
        Ok(wisp.internal_server_error())
      }
    }
  }

  case result {
    Ok(resp) -> resp
    Error(_) -> wisp.unprocessable_content()
  }
}

fn handler(req: Request, ctx: Context) -> Response {
  use req <- middleware(req)

  case wisp.path_segments(req) {
    ["users"] -> users_handler(req, ctx)
    ["users", id] -> user_handler(req, ctx, id)
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
  let context = Context(con)
  let handler = handler(_, context)

  let secret =
    result.unwrap(envoy.get("SECRET_KEY_BASE"), "wisp_secret_fallback")

  let assert Ok(_) =
    wisp_mist.handler(handler, secret)
    |> mist.new
    |> mist.port(8080)
    |> mist.start

  process.sleep_forever()
}
