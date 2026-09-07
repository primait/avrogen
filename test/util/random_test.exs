defmodule Avrogen.Util.RandomTest do
  use ExUnit.Case, async: true

  alias Avrogen.Util.Random

  setup do
    seed = :rand.seed(:default)

    {:ok, %{seed: seed}}
  end

  describe "datetime/3" do
    test "fails with `FunctionClauseError` when provided with t:Date/0 `start_date` and `end_date` structs",
         %{seed: seed} do
      start_date = Date.utc_today()
      end_date = Date.utc_today()

      assert_raise FunctionClauseError, fn ->
        Random.datetime(seed, start_date, end_date)
      end
    end
  end
end
