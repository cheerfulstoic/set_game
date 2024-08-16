defmodule SetGame.Game.Server do
  alias SetGame.Game.Deck
  alias SetGame.Game.PlayersRegistry

  @colors MapSet.new(~w[
    #191970
    #006400
    #ff0000
    #ffd700
    #00ff00
    #00ffff
    #ff00ff
    #ffb6c1
  ])

  use GenServer

  defmodule Player do
    defstruct name: nil, color: nil, score: 0, voted_to_draw_more: false, online: true

    def new(player_name, color) when is_binary(player_name) and is_binary(color) do
      %Player{
        name: player_name,
        color: color
      }
    end
  end

  def start do
    new_id =
      1..5
      |> Enum.map(fn _ -> 64 + :rand.uniform(26) end)
      |> to_string()

    with {:ok, _} <- GenServer.start(__MODULE__, new_id, name: name(new_id)) do
      {:ok, new_id}
    end
  end

  def register_as(game_id, player_name) do
    with {:ok, standardized_name} <- PlayersRegistry.register_as(game_id, player_name) do
      call(game_id, {:register_as, {player_name, standardized_name}})
    end
  end

  # def send_updates(game_id) do
  #   send(name(game_id), :send_updates)
  # end

  # def send_player_update(game_id) do
  #   send(name(game_id), :send_player_update)
  # end

  defmodule GameNotFoundError do
    defexception [:game_id]

    def exception(game_id) do
      %__MODULE__{game_id: game_id}
    end

    def message(%__MODULE__{game_id: game_id}) do
      "Game with ID #{game_id} not found"
    end
  end

  def call(game_id, message) do
    case Process.whereis(name(game_id)) do
      nil -> {:error, GameNotFoundError.exception(game_id)}
      pid -> GenServer.call(pid, message)
    end
  end

  def submit_guess(game_id, cards) do
    GenServer.call(name(game_id), {:submit_guess, cards})
  end

  def vote_to_draw_more(game_id) do
    GenServer.call(name(game_id), :vote_to_draw_more)
  end

  def init(game_id) do
    deck =
      Deck.new()
      |> Deck.shuffle()

    {face_up_cards, deck} = Deck.draw(deck, 12)

    {:ok,
     %{
       game_id: game_id,
       face_up_cards: face_up_cards,
       draw_pile: deck,
       players: %{}
     }}
  end

  defmodule NoMoreColorsAvailableError do
    defexception message: "No more colors available"

    def exception, do: %__MODULE__{}
  end

  def handle_call({:register_as, {player_name, standardized_name}}, {pid, _}, state) do
    Process.monitor(pid)

    used_colors = Enum.map(state.players, fn {_, player} -> player.color end)

    @colors
    |> Enum.find(fn color -> color not in used_colors end)
    |> case do
      nil ->
        {:reply, {:error, NoMoreColorsAvailableError.exception()}, state}

      unused_color ->
        player = Player.new(player_name, unused_color)

        send(self(), :send_updates)
        send(self(), :send_player_update)

        {:reply, {:ok, player},
         Map.update!(state, :players, &Map.put(&1, standardized_name, player))}
    end
  end

  def handle_call({:submit_guess, guessed_cards}, {pid, _}, state) do
    was_a_set? = Deck.set?(guessed_cards)

    state =
      if was_a_set? do
        face_up_cards =
          Enum.map(state.face_up_cards, fn card ->
            if card not in guessed_cards do
              card
            end
          end)

        state
        |> Map.put(:face_up_cards, face_up_cards)
        # |> Map.put(:draw_pile, face_up_cards)
        |> tap(fn _ -> send(self(), :send_updates) end)
      else
        state
      end

    state =
      update_player(state, pid, fn player ->
        adjustment = if(was_a_set?, do: 1, else: -1)

        Map.update!(player, :score, &(&1 + adjustment))
      end)

    broadcast(state.game_id, "guess_made", %{
      player: get_player(state, pid),
      cards: guessed_cards,
      was_a_set: was_a_set?
    })

    send(self(), :send_player_update)

    {:reply, {:ok, if(was_a_set?, do: :correct, else: :incorrect)}, state}
  end

  def handle_call(:vote_to_draw_more, {pid, _}, state) do
    state =
      state
      |> update_player(pid, fn player -> Map.put(player, :voted_to_draw_more, true) end)
      |> then(fn state ->
        all_ready_to_draw? = Enum.all?(players(state), fn player -> player.voted_to_draw_more end)

        if all_ready_to_draw? do
          {new_face_up_cards, draw_pile} = Deck.draw(state.draw_pile, 3)

          dbg(new_face_up_cards)

          send(self(), :send_updates)

          state
          |> Map.update!(:players, fn players ->
            Map.new(players, fn {name, player} ->
              {name, Map.put(player, :voted_to_draw_more, false)}
            end)
          end)
          |> Map.update!(:face_up_cards, fn face_up_cards ->
            {face_up_cards, new_face_up_cards} =
              Enum.map_reduce(face_up_cards, new_face_up_cards, fn
                card, [] -> {card, []}
                nil, [new_card | rest_of_new_cards] -> {new_card, rest_of_new_cards}
                card, new_cards -> {card, new_cards}
              end)

            Enum.reject(face_up_cards ++ new_face_up_cards, &is_nil/1)
          end)
          |> Map.put(:draw_pile, draw_pile)
        else
          state
        end
      end)

    send(self(), :send_player_update)

    {:reply, :ok, state}
  end

  def handle_info(:send_updates, state) do
    broadcast(state.game_id, "game_update", %{face_up_cards: state.face_up_cards})

    {:noreply, state}
  end

  def handle_info(:send_player_update, state) do
    broadcast(state.game_id, "players_update", %{players: Map.values(state.players)})

    {:noreply, state}
  end

  # def handle_info({:EXIT, exited_pid, :shutdown}, state) do
  #   {:noreply, cleanup_player(state, exited_pid)}
  # end

  # def handle_info({:EXIT, exited_pid, {:shutdown, :closed}}, state) do
  #   {:noreply, cleanup_player(state, exited_pid)}
  # end

  def handle_info({:EXIT, _pid, reason}, state) do
    Logger.warn("UNEXPECTED EXIT: with reason #{inspect(reason)}")

    {:stop, reason, state}
  end

  def handle_info({:DOWN, ref, :process, pid, reason}, state) do
    IO.inspect(reason, label: :DOWN_REASON)

    update_player(state, pid, fn player -> Map.put(player, :online, false) end)

    {:noreply, state}
  end

  # defp cleanup_player(state, given_pid) do
  #   send(self(), :send_player_update)

  #   Map.update!(state, :players, & Players.delete(&1, given_pid))
  # end

  defp update_player(state, pid, adjustment) do
    standardized_name = PlayersRegistry.get(state.game_id, pid)

    state
    |> Map.update!(:players, &Map.update!(&1, standardized_name, adjustment))
  end

  def get_player(state, pid) do
    standardized_name = PlayersRegistry.get(state.game_id, pid)

    Map.get(state.players, standardized_name)
  end

  def players(state) do
    PlayersRegistry.names(state.game_id)
    |> Enum.map(&Map.get(state.players, &1))
  end

  defp broadcast(game_id, event, payload) do
    for pid <- PlayersRegistry.pids(game_id) do
      send(pid, %{event: event, payload: payload})
    end
  end

  defp name(game_id) do
    :"#{__MODULE__}-#{game_id}"
  end
end
