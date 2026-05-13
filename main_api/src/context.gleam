import gleam/json
import gleam/option.{type Option, unwrap}
import gleam/time/calendar
import gleam/time/timestamp
import pog
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

pub fn user_to_json(user: User) {
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

pub fn timestamp_to_json(ts: timestamp.Timestamp) {
  json.string(timestamp.to_rfc3339(ts, calendar.utc_offset))
}
