defmodule SetGame.Game.PlayersRegistryTest do
  use ExUnit.Case, async: false

  alias SetGame.Game.PlayersRegistry

  setup do
    PlayersRegistry.clear()

    :ok
  end

  describe ".register_as" do
    test "Registering with a name" do
      assert {:ok, "alice"} = PlayersRegistry.register_as("ABCDE", "Alice")
    end

    test "Registering with a name twice" do
      game_id1 = "ABCDE"
      game_id2 = "ABCDD"

      assert {:ok, "alice"} = PlayersRegistry.register_as(game_id1, "Alice")

      assert {:error, %PlayersRegistry.AlreadyRegisteredError{player_name: "Alice"}} =
               PlayersRegistry.register_as(game_id1, "Alice")

      assert {:error, %PlayersRegistry.AlreadyRegisteredError{player_name: "alice"}} =
               PlayersRegistry.register_as(game_id1, "alice")

      assert {:error, %PlayersRegistry.AlreadyRegisteredError{player_name: "aLiCe"}} =
               PlayersRegistry.register_as(game_id1, "aLiCe")

      assert {:error, %PlayersRegistry.AlreadyRegisteredError{player_name: "Alice "}} =
               PlayersRegistry.register_as(game_id1, "Alice ")

      assert {:error, %PlayersRegistry.AlreadyRegisteredError{player_name: " Alice \n "}} =
               PlayersRegistry.register_as(game_id1, " Alice \n ")

      assert {:ok, "bob"} = PlayersRegistry.register_as(game_id1, "Bob")

      assert {:error, %PlayersRegistry.AlreadyRegisteredError{player_name: "Bob"}} =
               PlayersRegistry.register_as(game_id1, "Bob")

      assert {:ok, "alice"} = PlayersRegistry.register_as(game_id2, "Alice")
      assert {:ok, "bob"} = PlayersRegistry.register_as(game_id2, "Bob")
    end
  end
end
