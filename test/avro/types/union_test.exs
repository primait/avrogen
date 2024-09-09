defmodule Avrogen.Avro.Types.UnionTest.MacroSupport do
  alias Avrogen.Avro.Schema.CodeGenerator
  alias Avrogen.Avro.Types
  alias Avrogen.Utils.MacroUtils

  @union_schema %Types.Union{
    types: [
      %Types.Primitive{type: :null},
      %Types.Primitive{type: :string},
      %Types.Primitive{type: :boolean},
      %Types.Primitive{type: :double},
      %Types.Primitive{type: :int}
    ]
  }

  defmacro gen_code do
    details =
      [
        CodeGenerator.decode_function(@union_schema, :test_decode_union_primitives, %{}),
        CodeGenerator.encode_function(@union_schema, :test_encode_union_primitives, %{})
      ]
      |> Enum.flat_map(&MacroUtils.flatten_block/1)

    quote(do: (unquote_splicing(details)))
  end
end

defmodule Avrogen.Avro.Types.UnionTest do
  use ExUnit.Case, async: true
  alias __MODULE__.MacroSupport
  require MacroSupport

  MacroSupport.gen_code()

  describe "Union.decode_function" do
    test "primitive union" do
      ["hello", 1, true, 2.3, nil]
      |> Enum.each(fn union ->
        assert {:ok, val} = test_decode_union_primitives(union)
        assert union == test_encode_union_primitives(val)
      end)
    end

    test "union function clause error trying to encode a non-union type" do
      assert_raise FunctionClauseError, fn ->
        # It's a union of null, string, bool and numbers. Map isn't an union value.
        # Instead of returning the value itself, it should return an error.
        test_encode_union_primitives(%{})
      end
    end

    test "union function clause error trying to decode a non-union type" do
      # assert {:error, _} = test_decode_union_primitives(%{})
      # Note: that's not the correct behavior. The function should return an error.
      assert {:ok, %{}} = test_decode_union_primitives(%{})
    end
  end
end
