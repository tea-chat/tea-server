import context
import dot_env as dot
import envoy
import gleam/erlang/process
import gleam/result
import mist
import pog
import routes
import wisp
import wisp/wisp_mist

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
  let context = context.Context(con)
  let handler = routes.handler(_, context)

  let secret =
    result.unwrap(envoy.get("SECRET_KEY_BASE"), "wisp_secret_fallback")

  let assert Ok(_) =
    wisp_mist.handler(handler, secret)
    |> mist.new
    |> mist.port(8080)
    |> mist.start

  process.sleep_forever()
}
