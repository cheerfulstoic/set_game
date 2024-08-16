defmodule SetGame.Game do
  alias SetGame.Game.PlayersRegistry
  alias SetGame.Game.Server

  def register_as(game_id, player_name) do
    Server.register_as(game_id, player_name)
  end

  def submit_guess(game_id, cards) do
    Server.submit_guess(game_id, cards)
  end

  def vote_to_draw_more(game_id) do
    Server.vote_to_draw_more(game_id)
  end
end
