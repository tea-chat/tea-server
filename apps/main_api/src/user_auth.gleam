import argus
import context
import gleam/bit_array
import gleam/bool
import gleam/crypto
import gleam/dynamic/decode
import gleam/http
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import gleam/time/timestamp
import sql
import wisp.{type Request, type Response}
import youid/uuid

pub fn login_handler(req: Request, ctx: context.Context) -> Response {
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

        // make sure there is only one row
        use row <- result.try(case user.rows {
          [row] -> Ok(row)
          _ -> Error(wisp.internal_server_error())
        })

        let userauth = context.UserAuth(row.id, row.email, row.password_hash)

        // check password
        use valid <- result.try(
          argus.verify(userauth.password_hash, password)
          |> result.map_error(fn(_) { wisp.internal_server_error() }),
        )

        // send the reaper after them if it was invalid
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

        // make sure something isnt fishy
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

// TODO
// fn code_exchange_handler(req: Request, ctx: context.Context) {
//   // verify challenge
//   // generate token
//   // return token and expiry
//   todo
// }

pub fn require_auth(
  req: Request,
  ctx: context.Context,
  handler: fn(uuid.Uuid) -> Response,
) {
  case list.key_find(req.headers, "authorization") {
    Ok(auth_header) -> {
      case string.split_once(auth_header, "Bearer ") {
        Ok(#("", token)) -> {
          let token_hash =
            bit_array.from_string(token)
            |> crypto.hash(crypto.Sha256, _)
            |> bit_array.base16_encode()
          case sql.find_user_by_token(ctx.db, token_hash) {
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
