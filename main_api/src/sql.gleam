//// This module contains the code to run the sql queries defined in
//// `./src/sql`.
//// > 🐿️ This module was generated automatically using v4.6.0 of
//// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
////

import gleam/dynamic/decode
import gleam/option.{type Option}
import gleam/time/timestamp.{type Timestamp}
import pog
import youid/uuid.{type Uuid}

/// Runs the `delete_user` query
/// defined in `./src/sql/delete_user.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn delete_user(
  db: pog.Connection,
  arg_1: Uuid,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "delete from users
where id = $1;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `find_user` query
/// defined in `./src/sql/find_user.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type FindUserRow {
  FindUserRow(
    id: Uuid,
    username: String,
    display_name: String,
    joined: Timestamp,
    bio: Option(String),
  )
}

/// Runs the `find_user` query
/// defined in `./src/sql/find_user.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn find_user(
  db: pog.Connection,
  arg_1: Uuid,
) -> Result(pog.Returned(FindUserRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, uuid_decoder())
    use username <- decode.field(1, decode.string)
    use display_name <- decode.field(2, decode.string)
    use joined <- decode.field(3, pog.timestamp_decoder())
    use bio <- decode.field(4, decode.optional(decode.string))
    decode.success(FindUserRow(id:, username:, display_name:, joined:, bio:))
  }

  "select id, username, display_name, joined, bio from users
where id = $1;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `find_user_by_email` query
/// defined in `./src/sql/find_user_by_email.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type FindUserByEmailRow {
  FindUserByEmailRow(id: Uuid, email: String, password_hash: String)
}

/// Runs the `find_user_by_email` query
/// defined in `./src/sql/find_user_by_email.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn find_user_by_email(
  db: pog.Connection,
  arg_1: String,
) -> Result(pog.Returned(FindUserByEmailRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, uuid_decoder())
    use email <- decode.field(1, decode.string)
    use password_hash <- decode.field(2, decode.string)
    decode.success(FindUserByEmailRow(id:, email:, password_hash:))
  }

  "select id, email, password_hash from users
where email = $1;
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `find_user_by_token` query
/// defined in `./src/sql/find_user_by_token.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type FindUserByTokenRow {
  FindUserByTokenRow(user_id: Uuid)
}

/// Runs the `find_user_by_token` query
/// defined in `./src/sql/find_user_by_token.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn find_user_by_token(
  db: pog.Connection,
  arg_1: String,
) -> Result(pog.Returned(FindUserByTokenRow), pog.QueryError) {
  let decoder = {
    use user_id <- decode.field(0, uuid_decoder())
    decode.success(FindUserByTokenRow(user_id:))
  }

  "select user_id from sessions
where token_hash = $1;
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `find_users` query
/// defined in `./src/sql/find_users.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type FindUsersRow {
  FindUsersRow(
    id: Uuid,
    username: String,
    display_name: String,
    joined: Timestamp,
    bio: Option(String),
  )
}

/// Runs the `find_users` query
/// defined in `./src/sql/find_users.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn find_users(
  db: pog.Connection,
) -> Result(pog.Returned(FindUsersRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, uuid_decoder())
    use username <- decode.field(1, decode.string)
    use display_name <- decode.field(2, decode.string)
    use joined <- decode.field(3, pog.timestamp_decoder())
    use bio <- decode.field(4, decode.optional(decode.string))
    decode.success(FindUsersRow(id:, username:, display_name:, joined:, bio:))
  }

  "select id, username, display_name, joined, bio from users;
"
  |> pog.query
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `insert_auth_code` query
/// defined in `./src/sql/insert_auth_code.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type InsertAuthCodeRow {
  InsertAuthCodeRow(user_id: Uuid, expires_at: Timestamp)
}

/// Runs the `insert_auth_code` query
/// defined in `./src/sql/insert_auth_code.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn insert_auth_code(
  db: pog.Connection,
  arg_1: String,
  arg_2: Uuid,
  arg_3: String,
  arg_4: String,
) -> Result(pog.Returned(InsertAuthCodeRow), pog.QueryError) {
  let decoder = {
    use user_id <- decode.field(0, uuid_decoder())
    use expires_at <- decode.field(1, pog.timestamp_decoder())
    decode.success(InsertAuthCodeRow(user_id:, expires_at:))
  }

  "insert into auth_codes (code_hash, user_id, code_challenge, code_challenge_method)
values ($1, $2, $3, $4)
returning user_id, expires_at;
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(uuid.to_string(arg_2)))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `insert_user` query
/// defined in `./src/sql/insert_user.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type InsertUserRow {
  InsertUserRow(
    id: Uuid,
    username: String,
    display_name: String,
    joined: Timestamp,
    bio: Option(String),
  )
}

/// Runs the `insert_user` query
/// defined in `./src/sql/insert_user.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn insert_user(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: String,
  arg_4: String,
  arg_5: String,
) -> Result(pog.Returned(InsertUserRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, uuid_decoder())
    use username <- decode.field(1, decode.string)
    use display_name <- decode.field(2, decode.string)
    use joined <- decode.field(3, pog.timestamp_decoder())
    use bio <- decode.field(4, decode.optional(decode.string))
    decode.success(InsertUserRow(id:, username:, display_name:, joined:, bio:))
  }

  "insert into users (username, display_name, email, password_hash, bio)
values ($1, $2, $3, $4, $5)
returning id, username, display_name, joined, bio;
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.text(arg_5))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

// --- Encoding/decoding utils -------------------------------------------------

/// A decoder to decode `Uuid`s coming from a Postgres query.
///
fn uuid_decoder() {
  use bit_array <- decode.then(decode.bit_array)
  case uuid.from_bit_array(bit_array) {
    Ok(uuid) -> decode.success(uuid)
    Error(_) -> decode.failure(uuid.v7(), "Uuid")
  }
}
