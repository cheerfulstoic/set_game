defmodule SetGame.Game.Deck do
  @values %{
    count: [1, 2, 3],
    shape: ~w[diamond squiggle oval]a,
    shading: ~w[solid striped open]a,
    color: ~w[red green purple]a
  }

  def new() do
    for count <- @values.count,
        shape <- @values.shape,
        shading <- @values.shading,
        color <- @values.color do
      %{count: count, shape: shape, shading: shading, color: color}
    end
  end

  # FIXME: Temporary implementation for testing!
  def shuffle(deck) do
  IO.puts("SHUFFLING!")
    Enum.shuffle(deck)
    |> then(fn deck ->
      if set?(Enum.take(deck, 3)) do
        deck
      else
        shuffle(deck)
      end
    end)
  end

  # def shuffle(deck) do
  #   Enum.shuffle(deck)
  # end

  def draw(deck, n) do
    Enum.split(deck, n)
  end

  def set?(cards) do
    Map.keys(@values)
    |> Enum.all?(fn key ->
      value_is_setty?(cards, key)
    end)
  end

  defp value_is_setty?(cards, key) do
    cards
    |> Enum.map(& &1[key])
    |> Enum.uniq()
    |> case do
      [_] -> true
      [_, _, _] -> true
      _ -> false
    end
  end
end
