import argus
import context
import gleam/dynamic/decode
import gleam/http
import gleam/json
import gleam/list
import gleam/result
import sql
import user_auth as auth
import wisp.{type Request}
import youid/uuid

pub fn me_handler(req: Request, ctx: context.Context) {
  case req.method {
    http.Get -> {
      use user_id <- auth.require_auth(req, ctx)
      get_user_handler(ctx, user_id, user_id)
    }
    http.Delete -> {
      use user_id <- auth.require_auth(req, ctx)
      delete_user_handler(ctx, user_id)
    }
    _ -> wisp.method_not_allowed([http.Get, http.Delete])
  }
}

pub fn user_handler(req: Request, ctx: context.Context, id: String) {
  case req.method {
    http.Get -> {
      use user_id <- auth.require_auth(req, ctx)
      case uuid.from_string(id) {
        Ok(id) -> get_user_handler(ctx, id, user_id)
        Error(_) -> wisp.bad_request("Invalid id")
      }
    }
    _ -> wisp.method_not_allowed([http.Get])
  }
}

pub fn delete_user_handler(ctx: context.Context, id: uuid.Uuid) {
  case sql.delete_user(ctx.db, id) {
    Ok(_) -> wisp.no_content()
    Error(_) -> wisp.internal_server_error()
  }
}

pub fn get_user_handler(
  ctx: context.Context,
  id: uuid.Uuid,
  _user_id: uuid.Uuid,
) {
  case sql.find_user(ctx.db, id) {
    Ok(user) -> {
      case user.rows {
        [] -> wisp.not_found()
        [row] -> {
          let user =
            context.User(
              row.id,
              row.display_name,
              row.username,
              row.joined,
              row.bio,
            )

          context.user_to_json(user)
          |> json.to_string
          |> wisp.json_response(200)
        }
        _ -> wisp.internal_server_error()
      }
    }
    Error(_) -> wisp.internal_server_error()
  }
}

pub fn users_handler(req: Request, ctx: context.Context) {
  case req.method {
    http.Get -> get_users_handler(ctx)
    http.Post -> post_users_handler(req, ctx)
    _ -> wisp.method_not_allowed([http.Get, http.Post])
  }
}

pub fn get_users_handler(ctx: context.Context) {
  case sql.find_users(ctx.db) {
    Ok(users) -> {
      users.rows
      |> list.map(fn(row: sql.FindUsersRow) {
        context.User(
          row.id,
          row.display_name,
          row.username,
          row.joined,
          row.bio,
        )
      })
      |> json.array(context.user_to_json)
      |> json.to_string
      |> wisp.json_response(200)
    }
    Error(_) -> {
      wisp.internal_server_error()
    }
  }
}

pub fn post_users_handler(req: Request, ctx: context.Context) {
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
                  context.User(
                    row.id,
                    row.display_name,
                    row.username,
                    row.joined,
                    row.bio,
                  )

                wisp.log_info("User Created! " <> context.user_to_string(user))

                context.user_to_json(user)
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
