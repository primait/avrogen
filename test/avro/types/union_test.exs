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
  alias Avrogen.Schema.SchemaRegistry
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
        module |> Atom.to_string() |> String.ends_with?(Macro.camelize(root_module_name))
      end)

    %{record_module: record_module}
  end

  describe "Union.decode_function" do
    test "primitive union" do
      ["hello", 1, true, 2.3, nil]
      |> Enum.each(fn union ->
        assert {:ok, val} = test_decode_union_primitives(union)
        assert union == test_encode_union_primitives(val, [])
      end)
    end

    test "union function clause error trying to encode a non-union type" do
      assert_raise FunctionClauseError, fn ->
        # It's a union of null, string, bool and numbers. Map isn't an union value.
        # Instead of returning the value itself, it should return an error.
        test_encode_union_primitives(%{}, [])
      end
    end

    test "union function clause error trying to decode a non-union type" do
      assert {:error, _} = test_decode_union_primitives(%{})
    end
  end

  describe "record unions" do
    test "decoding values with matching args picks correct type", %{record_module: record_module} do
      assert {:ok, record} =
               record_module.from_avro_map(%{
                 "payment_plan" => %{
                   "identifier" => "monthly-plan",
                   "total_price" => %{
                     "deposit" => "45.67"
                   }
                 }
               })

      assert %{identifier: "monthly-plan", total_price: %{deposit: %Decimal{}}} =
               record.payment_plan

      assert Decimal.equal?(record.payment_plan.total_price.deposit, Decimal.new("45.67"))
    end

    test "decoding annual plan picks annual plan type", %{record_module: record_module} do
      assert {:ok, record} =
               record_module.from_avro_map(%{
                 "payment_plan" => %{
                   "total_price" => "120.00"
                 }
               })

      assert %{total_price: %Decimal{}} = record.payment_plan
      assert Decimal.equal?(record.payment_plan.total_price, Decimal.new("120.00"))
    end

    test "binary roundtrip preserves record union members", %{record_module: record_module} do
      schema = File.read!("test/roundtrip_schemas/TestRecord_Union.avsc")
      encoder = SchemaRegistry.make_encoder(schema)
      decoder = SchemaRegistry.make_decoder(schema)

      [
        %{},
        %{"total_price" => "120.00"},
        %{"identifier" => "monthly-plan", "total_price" => %{"deposit" => "45.67"}}
      ]
      |> Enum.each(fn payment_plan ->
        assert {:ok, record} = record_module.from_avro_map(%{"payment_plan" => payment_plan})

        avro_map = record_module.to_avro_map(record, encode_union_tags: true)

        encoded = encoder.(record_module.avro_fqn(), avro_map)
        decoded = decoder.(record_module.avro_fqn(), encoded)

        assert {:ok, ^record} = record_module.from_avro_map(decoded)
      end)
    end

    test "from_avro_map decodes tagged record union values", %{record_module: record_module} do
      [
        %{},
        %{"total_price" => "120.00"},
        %{"identifier" => "monthly-plan", "total_price" => %{"deposit" => "45.67"}}
      ]
      |> Enum.each(fn payment_plan ->
        assert {:ok, record} = record_module.from_avro_map(%{"payment_plan" => payment_plan})

        assert {:ok, ^record} =
                 record
                 |> record_module.to_avro_map()
                 |> record_module.from_avro_map()

        assert {:ok, ^record} =
                 record
                 |> record_module.to_avro_map(encode_union_tags: true)
                 |> record_module.from_avro_map()
      end)
    end

    test "to_avro_map only emits union tags when requested", %{record_module: record_module} do
      assert {:ok, record} =
               record_module.from_avro_map(%{
                 "payment_plan" => %{
                   "identifier" => "monthly-plan",
                   "total_price" => %{"deposit" => "45.67"}
                 }
               })

      assert %{"payment_plan" => %{"identifier" => "monthly-plan"}} =
               record_module.to_avro_map(record)

      assert %{"payment_plan" => {"events.v1.MonthlyPlan", _}} =
               record_module.to_avro_map(record, encode_union_tags: true)
    end
  end
end
