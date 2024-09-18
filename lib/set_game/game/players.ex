defmodule SetGame.Game.Players do
  # From: https://mokole.com/palette.html
  #@colors MapSet.new(~w[
  #  #191970
  #  #006400
  #  #ff0000
  #  #ffd700
  #  #00ff00
  #  #00ffff
  #  #ff00ff
  #  #ffb6c1
  #])

  # From: https://mokole.com/palette.html
  #@colors MapSet.new(~w[
  #  #2f4f4f
  #  #8b4513
  #  #228b22
  #  #4b0082
  #  #ff0000
  #  #00ff00
  #  #00ffff
  #  #0000ff
  #  #ff00ff
  #  #ffff54
  #  #6495ed
  #  #ff69b4
  #  #ffe4c4
  #])

  # From: https://sashamaps.net/docs/resources/20-colors/
  @colors MapSet.new(~w[
    #e6194b
    #3cb44b
    #ffe119
    #4363d8
    #f58231
    #911eb4
    #46f0f0
    #f032e6
    #bcf60c
    #fabebe
    #008080
    #e6beff
    #9a6324
    #fffac8
    #800000
    #aaffc3
    #808000
    #ffd8b1
    #000075
    #808080
    #ffffff
    #000000
  ])


  def new, do: %{}

  def to_list(players), do: Map.values(players)
  def pids(players), do: Map.keys(players)

  def get(players, pid), do: Map.get(players, pid)

  def delete(players, pid), do: Map.delete(players, pid)

  def add_player(players, pid, player_name) do
    if name_used?(players, player_name) do
      {:error, "Player name already in use"}
    else
      new_player =
        %{
          name: player_name,
          color: new_color(players),
          score: 0,
          voted_to_draw_more: false
        }

      {:ok, {Map.put(players, pid, new_player), new_player}}
    end
  end

  def adjust_score(players, pid, amount) do
    update_player(players, pid, fn player -> Map.update!(player, :score, & &1 + amount) end)
  end

  def mark_voted_to_draw_more(players, pid) do
    update_player(players, pid, fn player -> Map.put(player, :voted_to_draw_more, true) end)
  end

  def all_ready_to_draw?(players), do: Enum.all?(players, fn {_, p} -> p.voted_to_draw_more end)

  def reset_ready_to_draw(players) do
    Map.new(players, fn {pid, player} -> {pid, Map.put(player, :voted_to_draw_more, false)} end)
  end

  defp update_player(players, pid, update_fn) do
    Map.update!(players, pid, update_fn)
  end

  def name_used?(players, name), do: name in Enum.map(players, fn {_, p} -> p.name end)
  def color_used?(players, color), do: color in Enum.map(players, fn {_, p} -> p.color end)

  defp new_color(players) do
    used_colors = Enum.map(players, fn {_, p} -> p.color end)

    Enum.find(@colors, fn color -> color not in used_colors end)
  end
end


