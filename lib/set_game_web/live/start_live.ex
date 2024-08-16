defmodule SetGameWeb.StartLive do
  alias SetGame.Game

  use SetGameWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="container mx-auto">
      <!-- Start or join a game -->
      <h1 class="text-3xl font-bold text-center">Welcome to Set Game!</h1>

      <form phx-submit="start-or-join" class="bg-white shadow-md rounded px-8 pt-6 pb-8 mb-4">
        <input name="name" placeholder="Your name (required)" />

        <input name="game_id" placeholder="Game ID (optional)" />

        <.button
          type="submit"
          class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
        >
          Start or join a game
        </.button>
      </form>
    </div>
    """
  end

  # def mount(_params, _session, socket) do
  #   {:ok, assign(socket)}
  # end

  def handle_event("start-or-join", %{"game_id" => game_id, "name" => name}, socket) do
    case String.strip(name) do
      "" ->
        {:noreply, put_flash(socket, :error, "Name is required")}

      name ->
        if String.strip(game_id) == "" do
          case Game.Server.start() do
            {:ok, game_id} ->
              {:noreply, push_navigate(socket, to: ~p"/game/#{game_id}/as/#{name}")}

            {:error, _} ->
              {:noreply, socket}
          end
        else
          {:noreply, push_navigate(socket, to: ~p"/game/#{game_id}/as/#{name}")}
        end
    end
  end
end
