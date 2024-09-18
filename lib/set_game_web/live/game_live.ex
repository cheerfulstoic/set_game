defmodule SetGameWeb.GameLive do
  alias SetGame.Game

  use SetGameWeb, :live_view

  def render(assigns) do
    ~H"""
    <svg width="0" height="0">
      <!--  Define the patterns for the different fill colors  -->
      <pattern id="striped-red" patternUnits="userSpaceOnUse" width="4" height="4">
        <path d="M-1,1 H5" style="stroke:#e74c3c; stroke-width:1"></path>
      </pattern>
      <pattern id="striped-green" patternUnits="userSpaceOnUse" width="4" height="4">
        <path d="M-1,1 H5" style="stroke:#27ae60; stroke-width:1"></path>
      </pattern>
      <pattern id="striped-purple" patternUnits="userSpaceOnUse" width="4" height="4">
        <path d="M-1,1 H5" style="stroke:#8e44ad; stroke-width:1"></path>
      </pattern>
    </svg>
    <div class="x-auto">
      <p>Game ID: <strong><%= @game_id %></strong></p>
      <.button phx-click="vote-to-draw-more">Vote to Draw More</.button>

      <div class="border-2 rounded-lg m-2 p-1 grid grid-cols-3 gap-2">
        <%= for card <- @face_up_cards do %>
          <div>
            <%= if card do %>
              <%
                selected? = MapSet.member?(@selected_cards, card)
                incorrect_guess? = @incorrect_guess && card in @incorrect_guess.cards
              %>

              <.card card={card} selected_color={if(selected?, do: @current_player.color)} class={if(incorrect_guess?, do: "horizontal-shake")} />
            <% else %>
              <div>&nbsp;</div>
            <% end %>
          </div>
        <% end %>
      </div>

      <!-- showing all players with their associated colors in a grid -->
      <div>
        <%= for player <- @players do %>
          <div class="flex items-center">
            <div class="w-4 h-4 rounded-full" style={"background-color: #{player.color};"}></div>
            <p class="ml-2">
              <%= player.name %>
              <%= if player.name == @current_player.name do %>
                <strong>(you)</strong>
              <% end %>
              | <%= player.score %>
              | <%= if player.voted_to_draw_more, do: "*voted to draw more cards*" %>
            </p>
          </div>
        <% end %>
      </div>

      <%= if @correct_guess do %>
        <div class="p-4 rounded-lg mt-4">
          <p>
            Last correctly identified set (from <strong><%= @correct_guess.player.name %></strong>):

            <div class="grid grid-cols-3 gap-4">
              <%= for card <- @correct_guess.cards do %>
                <.card card={card} selected_color={nil} />
              <% end %>
            </div>
          </p>
        </div>
      <% end %>

    </div>
    """
  end

  # Make sure tailwind sees these class names
  # text-red-500
  # text-green-500
  # text-purple-500
  # border-solid
  # border-dotted
  attr :class, :string, default: nil
  def card(assigns) do
    ~H"""
    <%
      fill =
        case @card.shading do
          :solid -> @card.color
          :striped -> "url(#striped-#{@card.color})"
          :open -> "none"
        end
    %>

    <div
      class={["bg-gray-200 p-4 rounded-lg flex justify-around border-2 m-1", @class]}
      style={if(@selected_color, do: "border-color: #{@selected_color}", else: "border-color: transparent")}
      phx-click="toggle-card"
      phx-value-count={@card.count}
      phx-value-shape={@card.shape}
      phx-value-shading={@card.shading}
      phx-value-color={@card.color}
      >
      <%= for _ <- 1..@card.count do %>
        <!-- Uses flexbox to have them all in a row -->
        <div class={"text-#{@card.color}-500 w-1/3 flex justify-center"}>
          <svg viewBox="0 0 54 104" width="30%">
            <path d={shape_path_d(@card.shape)} fill={fill} stroke={@card.color}></path>
          </svg>
        </div>
      <% end %>
    </div>
    """
  end

  # %{count: 3, color: :purple, shape: :squiggle, shading: :open}

  # copied from https://codepen.io/jacob_124/pen/vdYdPX
  def shape_path_d(:diamond) do
    "M25 0 L50 50 L25 100 L0 50 Z"
  end
  def shape_path_d(:oval) do
    "M25,99.5C14.2,99.5,5.5,90.8,5.5,80V20C5.5,9.2,14.2,0.5,25,0.5S44.5,9.2,44.5,20v60 C44.5,90.8,35.8,99.5,25,99.5z"
  end
  def shape_path_d(:squiggle) do
    "M38.4,63.4c0,16.1,11,19.9,10.6,28.3c-0.5,9.2-21.1,12.2-33.4,3.8s-15.8-21.2-9.3-38c3.7-7.5,4.9-14,4.8-20 c0-16.1-11-19.9-10.6-28.3C1,0.1,21.6-3,33.9,5.5s15.8,21.2,9.3,38C40.4,50.6,38.5,57.4,38.4,63.4z"
  end

  def mount(%{"id" => _, "name" => ""}, _session, socket) do
    {:ok,
      socket
      |> put_fading_flash(:error, "Name is required")
      |> push_navigate(to: ~p"/")}
  end

  def mount(%{"id" => game_id, "name" => player_name}, _session, socket) do
    socket =
      assign(socket,
        game_id: game_id,
        current_player: nil,
        player_name: player_name,
        face_up_cards: [],
        selected_cards: MapSet.new(),
        incorrect_guess: nil,
        correct_guess: nil,
        players: []
      )

    socket =
      if connected?(socket) do
        case Game.Server.join(game_id, player_name) do
          {:ok, current_player} ->
            socket
            |> assign(:current_player, current_player)

          _ ->
            socket
            |> push_navigate(to: ~p"/")
            |> put_fading_flash(:error, "Player name '#{player_name}' already in use")
        end
      else
        socket
      end

    {:ok, socket}
  end

  def handle_info(%{event: "game_update", payload: %{face_up_cards: face_up_cards}}, socket) do
    {:noreply, assign(socket, face_up_cards: face_up_cards)}
  end

  def handle_info(%{event: "players_update", payload: %{players: players}}, socket) do
    {:noreply, assign(socket, players: players)}
  end

  def handle_info(%{event: "guess_made", payload: %{player: player, cards: guessed_cards, was_a_set: was_a_set?}}, socket) do
    {:noreply,
      socket =
        socket
        |> assign(:last_guessed_was_set, was_a_set?)
        |> then(fn socket ->
          current_player? = player.name == socket.assigns.current_player.name
          if was_a_set? do
            no_shared_cards_with_guess? =
              MapSet.new(guessed_cards)
              |> MapSet.disjoint?(socket.assigns.selected_cards)

            socket
            |> assign(:correct_guess, %{player: player, cards: guessed_cards})
            |> then(fn socket ->
              if no_shared_cards_with_guess? do
                socket
              else
                assign(socket, :selected_cards, MapSet.new())
              end
            end)
            |> then(fn socket ->
              if(current_player?, do: socket, else: put_fading_flash(socket, :info, "#{player.name} found a set!"))
            end)
          else
            Process.send_after(self(), :clear_incorrect_guess, 1_700)

            socket
            |> assign(:incorrect_guess, %{player: player, cards: guessed_cards})
            |> then(fn socket ->
              if(current_player?, do: socket, else: put_fading_flash(socket, :error, "#{player.name} made an incorrect guess."))
            end)
          end
        end)}
  end


  def handle_event("toggle-card", %{"count" => count, "shape" => shape, "shading" => shading, "color" => color}, socket) do
    # Game.Server.toggle_card(%{count: count, shape: shape, shading: shading, color: color})

    new_selected_card = %{
      count: String.to_integer(count),
      shape: String.to_existing_atom(shape),
      shading: String.to_existing_atom(shading),
      color: String.to_existing_atom(color)
    }
    socket =
      socket
      |> update(:selected_cards, fn cards ->
        if MapSet.member?(cards, new_selected_card) do
          MapSet.delete(cards, new_selected_card)
        else
          MapSet.put(cards, new_selected_card)
        end
      end)
      |> then(fn socket ->
        cards = socket.assigns.selected_cards

        if MapSet.size(cards) == 3 do
          case Game.Server.submit_guess(socket.assigns.game_id, cards) do
            :correct ->
              socket
              |> put_fading_flash(:info, "CORRECT!")

            :incorrect ->
              socket
              |> put_fading_flash(:error, "NOT A SET")
          end
          |> assign(:selected_cards, MapSet.new())
        else
          socket
        end
      end)

    {:noreply, socket}
  end

  def handle_event("vote-to-draw-more", _, socket) do
    :ok = Game.Server.vote_to_draw_more(socket.assigns.game_id)

    {:noreply, socket}
  end

  def put_fading_flash(socket, type, message) do
    Process.send_after(self(), :clear_flash, 2_000)

    put_flash(socket, type, message)
  end

  def handle_info(:clear_incorrect_guess, socket) do
    {:noreply, assign(socket, incorrect_guess: nil)}
  end

  def handle_info(:clear_flash, socket) do
    {:noreply, clear_flash(socket)}
  end
end
