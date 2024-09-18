defmodule SetGame.Game.Server do
  alias SetGame.Game.Deck
  alias SetGame.Game.Players

  use GenServer

  def start do
    new_id =
      (1..5)
      |> Enum.map(fn _ -> 64 + :rand.uniform(26) end)
      |> to_string()

    with {:ok, _} <- GenServer.start(__MODULE__, new_id, name: name(new_id)) do
      {:ok, new_id}
    end
  end

  def join(id, player_name) do
    case Process.whereis(name(id)) do
      nil ->
        {:error, :not_found}

      pid ->
        GenServer.call(pid, {:join, player_name})
    end
  end

  def submit_guess(id, cards) do
    GenServer.call(name(id), {:submit_guess, cards})
  end

  def vote_to_draw_more(id) do
    GenServer.call(name(id), :vote_to_draw_more)
  end

  def init(game_id) do
    deck =
      Deck.new()
      |> Deck.shuffle()

    {face_up_cards, deck} = Deck.draw(deck, 12)

    {:ok, %{
      game_id: game_id,
      face_up_cards: face_up_cards,
      draw_pile: deck,
      players: Players.new()
    }}
  end

  def handle_call({:join, player_name}, {pid, _}, state) do
    Process.monitor(pid)

    case Players.add_player(state.players, pid, player_name) do
      {:ok, {players, new_player}} ->
        send(self(), :send_updates)
        send(self(), :send_player_update)

        {:reply, {:ok, new_player}, Map.put(state, :players, players)}

      {:error, message} ->
        {:reply, {:error, message}, state}
    end
  end

  def handle_call({:submit_guess, guessed_cards}, {pid, _}, state) do
    was_a_set? = Deck.set?(guessed_cards)

    state =
      if was_a_set? do
        face_up_cards = Enum.map(state.face_up_cards, fn card ->
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

    state = Map.update!(state, :players, & Players.adjust_score(&1, pid, if(was_a_set?, do: 1, else: -1)))

    broadcast(state, "guess_made", %{player: Players.get(state.players, pid), cards: guessed_cards, was_a_set: was_a_set?})
    send(self(), :send_player_update)

    {:reply, if(was_a_set?, do: :correct, else: :incorrect), state}
  end

  def handle_call(:vote_to_draw_more, {pid, _}, state) do
    state =
      Map.update!(state, :players, & Players.mark_voted_to_draw_more(&1, pid))
      |> then(fn state ->
        if Players.all_ready_to_draw?(state.players) do
          {new_face_up_cards, draw_pile} = Deck.draw(state.draw_pile, 3)

          send(self(), :send_updates)

          state
          |> Map.update!(:players, & Players.reset_ready_to_draw/1)
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
    broadcast(state, "game_update", %{face_up_cards: state.face_up_cards})

    {:noreply, state}
  end

  def handle_info(:send_player_update, state) do
    broadcast(state, "players_update", %{players: Players.to_list(state.players)})

    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    {:noreply, cleanup_player(state, pid)}
  end

  def handle_info(message, state) do
    {:noreply, state}
  end

  defp cleanup_player(state, given_pid) do
    send(self(), :send_player_update)

    Map.update!(state, :players, & Players.delete(&1, given_pid))
  end

  defp broadcast(state, event, payload) do
    for pid <- Players.pids(state.players) do
      send(pid, %{event: event, payload: payload})
    end
  end

  defp name(id) do
    :"#{__MODULE__}-#{id}"
  end
end
