defmodule SetGame.Repo do
  use Ecto.Repo,
    otp_app: :set_game,
    adapter: Ecto.Adapters.Postgres
end
