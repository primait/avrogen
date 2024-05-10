defmodule Avrogen.Avro.Types.MapTest.MacroSupport do
  alias Avrogen.Avro.Schema.CodeGenerator
  alias Avrogen.Avro.Types
  alias Avrogen.Utils.MacroUtils

  @map_schema %Types.Map{default: %{}, value_schema: %Types.Primitive{type: :string}}

  @record_schema %Types.Record{
    name: "ValueRecord",
    namespace: "test",
    fields: [%Types.Record.Field{name: "f1", type: %Types.Primitive{type: :int}}]
  }

  @map_schema_record %Types.Map{default: %{}, value_schema: @record_schema}

  defmacro gen_code do
    details =
      [
        CodeGenerator.decode_function(@map_schema, :test_decode_map, %{}),
        CodeGenerator.encode_function(@map_schema, :test_encode_map, %{}),
        CodeGenerator.decode_function(@map_schema_record, :test_decode_record_map, %{}),
        CodeGenerator.encode_function(@map_schema_record, :test_encode_record_map, %{})
      ]
      |> Enum.flat_map(&MacroUtils.flatten_block/1)

    quote(do: (unquote_splicing(details)))
  end
end

defmodule Avrogen.Avro.Types.MapTest do
  use ExUnit.Case, async: true
  alias __MODULE__.MacroSupport
  require MacroSupport

  defmodule ValueRecord do
    use TypedStruct

    typedstruct do
      field :f1, integer()
    end

    def from_avro_map(%{"f1" => f1}), do: {:ok, %__MODULE__{f1: f1}}
    def to_avro_map(%__MODULE__{f1: f1}), do: %{"f1" => f1}
  end

  MacroSupport.gen_code()

  describe "Map.decode_function" do
    test "primitive-valued map" do
      initial_map = %{"a" => "b"}
      assert {:ok, val} = test_decode_map(initial_map)
      assert initial_map == test_encode_map(val)

      assert_raise FunctionClauseError, fn -> test_encode_map(%{"a" => 1}) end
    end

    test "record-valued map" do
      initial_map = %{"a" => %{"f1" => 42}}
      assert {:ok, val} = test_decode_record_map(initial_map)
      assert initial_map == test_encode_record_map(val)
    end
  end
end
