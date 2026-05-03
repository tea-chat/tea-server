import argus
import dot_env as dot
import envoy
import gleam/bit_array
import gleam/bool
import gleam/crypto
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/http
import gleam/json
import gleam/list
import gleam/option.{type Option, unwrap}
import gleam/result
import gleam/string
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

pub type UserAuth {
  UserAuth(id: uuid.Uuid, email: String, password_hash: String)
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
  <> ") ID: "
  <> uuid.to_string(user.id)
  <> " Bio: "
  <> unwrap(user.bio, "")
}

fn timestamp_to_json(ts: timestamp.Timestamp) {
  json.string(timestamp.to_rfc3339(ts, calendar.utc_offset))
}

fn me_handler(req: Request, ctx: Context) {
  case req.method {
    http.Get -> {
      use user_id <- require_auth(req, ctx)
      get_user_handler(ctx, user_id, user_id)
    }
    http.Delete -> {
      use user_id <- require_auth(req, ctx)
      delete_user_handler(ctx, user_id)
    }
    _ -> wisp.method_not_allowed([http.Get, http.Delete])
  }
}

fn user_handler(req: Request, ctx: Context, id: String) {
  case req.method {
    http.Get -> {
      use user_id <- require_auth(req, ctx)
      case uuid.from_string(id) {
        Ok(id) -> get_user_handler(ctx, id, user_id)
        Error(_) -> wisp.bad_request("Invalid id")
      }
    }
    _ -> wisp.method_not_allowed([http.Get])
  }
}

fn delete_user_handler(ctx: Context, id: uuid.Uuid) {
  case sql.delete_user(ctx.db, id) {
    Ok(_) -> wisp.no_content()
    Error(_) -> wisp.internal_server_error()
  }
}

fn get_user_handler(ctx: Context, id: uuid.Uuid, _user_id: uuid.Uuid) {
  case sql.find_user(ctx.db, id) {
    Ok(user) -> {
      case user.rows {
        [] -> wisp.not_found()
        [row] -> {
          let user =
            User(row.id, row.display_name, row.username, row.joined, row.bio)

          user_to_json(user)
          |> json.to_string
          |> wisp.json_response(200)
        }
        _ -> wisp.internal_server_error()
      }
    }
    Error(_) -> wisp.internal_server_error()
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
    Ok(users) -> {
      users.rows
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
      use email <- decode.field("email", decode.string)
      use password <- decode.field("password", decode.string)
      use bio <- decode.optional_field("bio", "", decode.string)
      decode.success(#(username, display_name, email, password, bio))
    }
    use #(username, display_name, email, password, bio) <- result.try(
      decode.run(json, decoder),
    )

    let salt = argus.gen_salt()

    case
      argus.hasher()
      |> argus.hash(password, salt)
    {
      Ok(hashes) -> {
        let password_hash = hashes.encoded_hash

        case
          sql.insert_user(
            ctx.db,
            username,
            display_name,
            email,
            password_hash,
            bio,
          )
        {
          Ok(r) -> {
            case r.rows {
              [row] -> {
                let user =
                  User(
                    row.id,
                    row.display_name,
                    row.username,
                    row.joined,
                    row.bio,
                  )

                wisp.log_info("User Created! " <> user_to_string(user))

                user_to_json(user)
                |> json.to_string
                |> wisp.json_response(200)
                |> Ok()
              }
              _ -> Ok(wisp.internal_server_error())
            }
          }
          Error(_) -> Ok(wisp.internal_server_error())
        }
      }
      Error(_) -> Ok(wisp.internal_server_error())
    }
  }

  case result {
    Ok(resp) -> resp
    Error(_) -> wisp.unprocessable_content()
  }
}

fn login_handler(req: Request, ctx: Context) -> Response {
  case req.method {
    http.Post -> {
      use json <- wisp.require_json(req)

      let result = {
        let decoder = {
          use email <- decode.field("email", decode.string)
          use password <- decode.field("password", decode.string)
          use challenge <- decode.field("challenge", decode.string)
          decode.success(#(email, password, challenge))
        }

        use #(email, password, challenge) <- result.try(
          decode.run(json, decoder)
          |> result.map_error(fn(_) { wisp.unprocessable_content() }),
        )

        use user <- result.try(
          sql.find_user_by_email(ctx.db, email)
          |> result.map_error(fn(_) { wisp.internal_server_error() }),
        )
        use row <- result.try(case user.rows {
          [row] -> Ok(row)
          _ -> Error(wisp.internal_server_error())
        })

        let userauth = UserAuth(row.id, row.email, row.password_hash)

        use valid <- result.try(
          argus.verify(userauth.password_hash, password)
          |> result.map_error(fn(_) { wisp.internal_server_error() }),
        )
        use <- bool.guard(
          when: !valid,
          return: Error(
            wisp.response(401) |> wisp.set_body(wisp.Text("Invalid password")),
          ),
        )
        let auth_code =
          crypto.strong_random_bytes(128) |> bit_array.base64_url_encode(True)
        let code_hash =
          bit_array.from_string(auth_code)
          |> crypto.hash(crypto.Sha256, _)
          |> bit_array.base16_encode()

        use inserted <- result.try(
          sql.insert_auth_code(
            ctx.db,
            code_hash,
            userauth.id,
            challenge,
            "S256",
          )
          |> result.map_error(fn(_) { wisp.internal_server_error() }),
        )
        use row <- result.try(case inserted.rows {
          [row] -> Ok(row)
          _ -> Error(wisp.internal_server_error())
        })

        let body =
          json.object([
            #("id", json.string(uuid.to_string(row.user_id))),
            #("code", json.string(auth_code)),
            #(
              "expires_at",
              json.float(timestamp.to_unix_seconds(row.expires_at)),
            ),
          ])

        wisp.response(200)
        |> wisp.json_body(json.to_string(body))
        |> Ok()
      }

      case result {
        Ok(resp) -> resp
        Error(resp) -> resp
      }
    }
    _ -> wisp.method_not_allowed([http.Post])
  }
}

// fn code_exchange_handler(req: Request, ctx: Context) {
//   // verify challenge
//   // generate token
//   // return token and expiry
//   todo
// }

fn require_auth(req: Request, ctx: Context, handler: fn(uuid.Uuid) -> Response) {
  case list.key_find(req.headers, "authorization") {
    Ok(auth_header) -> {
      case string.split_once(auth_header, "Bearer ") {
        Ok(#("", token)) -> {
          case sql.find_user_by_token(ctx.db, token) {
            Ok(result) ->
              case result.rows {
                [row] -> handler(row.user_id)
                _ -> wisp.response(401)
              }
            Error(_) -> wisp.internal_server_error()
          }
        }
        _ -> wisp.response(401)
      }
    }
    Error(_) -> wisp.response(401)
  }
}

fn handler(req: Request, ctx: Context) -> Response {
  use req <- middleware(req)

  case wisp.path_segments(req) {
    ["users"] -> users_handler(req, ctx)
    ["users", id] -> user_handler(req, ctx, id)
    ["me"] -> me_handler(req, ctx)
    ["login"] -> login_handler(req, ctx)
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

  dot.new() |> dot.set_debug(False) |> dot.load
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
