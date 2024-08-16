defmodule SetGame.Game.PlayersRegistry do
  defmodule AlreadyRegisteredError do
    defexception [:player_name]

    def exception(player_name) do
      %__MODULE__{player_name: player_name}
    end

    def message(%__MODULE__{player_name: player_name}) do
      "Player name '#{player_name}' is already in use"
    end
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  def start_link(opts) do
    Registry.start_link(keys: :duplicate, name: opts[:name] || __MODULE__)
  end

  def clear do
    :ok = Registry.unregister_match(__MODULE__, :_, :_)
  end

  def register_as(game_id, player_name) do
    standardized_name = standardize_name(player_name)

    case get(game_id, standardized_name) do
      nil ->
        with {:ok, _} <- Registry.register(__MODULE__, game_id, standardized_name) do
          {:ok, standardized_name}
        end

      _ ->
        {:error, AlreadyRegisteredError.exception(player_name)}
    end
  end

  def get(game_id, given_pid) when is_pid(given_pid) do
    Registry.lookup(__MODULE__, game_id)
    |> Enum.find_value(fn {pid, standardized_name} ->
      if(pid == given_pid, do: standardized_name)
    end)
  end

  def get(game_id, player_name) when is_binary(player_name) do
    given_standardized_name = standardize_name(player_name)

    Registry.lookup(__MODULE__, game_id)
    |> Enum.find(fn {_, standardized_name} -> standardized_name == given_standardized_name end)
    |> case do
      {_, standardized_name} ->
        standardized_name

      nil ->
        nil
    end
  end

  def names(game_id) do
    Registry.lookup(__MODULE__, game_id)
    |> Enum.map(fn {_, standardized_name} -> standardized_name end)
  end

  def pids(game_id) do
    Registry.lookup(__MODULE__, game_id)
    |> Enum.map(fn {pid, _} -> pid end)
  end

  defp standardize_name(name) do
    name
    |> String.trim()
    |> String.downcase()
  end

  defp unused_color(game_id) do
    used_colors =
      Registry.lookup(__MODULE__, game_id)
      |> Enum.map(fn {_, player} -> player.color end)

    Enum.find(@colors, fn color -> color not in used_colors end)
  end

  # Old...

  # def to_list(players), do: Map.values(players)
  # def pids(players), do: Map.keys(players)

  # def get(players, pid), do: Map.get(players, pid)

  # def delete(players, pid), do: Map.delete(players, pid)

  # def add_player(pid, player_name) do
  #   if name_used?(player_name) do
  #     {:error, "Player name already in use"}
  #   else
  #     new_player =
  #       %{
  #         name: player_name,
  #         color: new_color(players),
  #         score: 0,
  #         voted_to_draw_more: false
  #       }

  #     {:ok, {Map.put(players, pid, new_player), new_player}}
  #   end
  # end

  # def adjust_score(players, pid, amount) do
  #   update_player(players, pid, fn player -> Map.update!(player, :score, & &1 + amount) end)
  # end

  # def mark_voted_to_draw_more(players, pid) do
  #   update_player(players, pid, fn player -> Map.put(player, :voted_to_draw_more, true) end)
  # end

  # def all_ready_to_draw?(players), do: Enum.all?(players, fn {_, p} -> p.voted_to_draw_more end)

  # def reset_ready_to_draw(players) do
  #   Map.new(players, fn {pid, player} -> {pid, Map.put(player, :voted_to_draw_more, false)} end)
  # end

  # defp update_player(players, pid, update_fn) do
  #   Map.update!(players, pid, update_fn)
  # end

  # def name_used?(players, name), do: name in Enum.map(players, fn {_, p} -> p.name end)
  # def color_used?(players, color), do: color in Enum.map(players, fn {_, p} -> p.color end)
end
