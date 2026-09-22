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
  alias Avrogen.Test.SchemaHelpers
  require MacroSupport

  MacroSupport.gen_code()

  setup_all do
    Code.put_compiler_option(:ignore_already_consolidated, true)
    root_module_name = "TestRecord_Union"

    record_module =
      root_module_name
      |> then(&File.read!(Path.join("test/roundtrip_schemas", "#{&1}.avsc")))
      |> SchemaHelpers.generate_modules_from_schema()
      |> Enum.find(fn module ->
        module |> Atom.to_string() |> String.ends_with?(root_module_name)
      end)

    %{record_module: record_module}
  end

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
      assert {:error, _} = test_decode_union_primitives(%{})
    end
  end

  describe "record unions" do
    test "decoding values with matching args picks correct type", %{record_module: record_module} do
      assert {:ok, record} =
               apply(record_module, :from_avro_map, [
                 %{
                   "payment_plan" => %{
                     "identifier" => "monthly-plan",
                     "total_price" => %{
                       "deposit" => "45.67"
                     }
                   }
                 }
               ])

      assert %{identifier: "monthly-plan", total_price: %{deposit: %Decimal{}}} =
               record.payment_plan

      assert Decimal.equal?(record.payment_plan.total_price.deposit, Decimal.new("45.67"))
    end

    test "decoding annual plan picks annual plan type", %{record_module: record_module} do
      assert {:ok, record} =
               apply(record_module, :from_avro_map, [
                 %{
                   "payment_plan" => %{
                     "total_price" => "120.00"
                   }
                 }
               ])

      assert %{total_price: %Decimal{}} = record.payment_plan
      assert Decimal.equal?(record.payment_plan.total_price, Decimal.new("120.00"))
    end
  end
end
