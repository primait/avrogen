defmodule AvrogenTest do
  use ExUnit.Case, async: false

  alias Avrogen.Schema.SchemaRegistry
  alias Avrogen.Test.SchemaHelpers

  setup_all do
    Code.put_compiler_option(:ignore_already_consolidated, true)

    schema =
      "test/roundtrip_schemas/TestRecord_Union.avsc"
      |> File.read!()
      |> Jason.decode!()
      |> Map.put("namespace", "avrogen.encoding")
      |> Jason.encode!()

    record_module =
      schema
      |> SchemaHelpers.generate_modules_from_schema()
      |> Enum.find(&(&1.avro_fqn() == "avrogen.encoding.TestRecord_Union"))

    encoder = SchemaRegistry.make_encoder(schema)
    decoder = SchemaRegistry.make_decoder(schema)

    :ets.new(SchemaRegistry, [:set, :protected, :named_table])
    :ets.insert(SchemaRegistry, {"all", schema, encoder, decoder})

    %{record_module: record_module}
  end

  test "schemaless encoding preserves overlapping record union members", %{
    record_module: record_module
  } do
    [
      %{},
      %{"total_price" => "120.00"},
      %{"identifier" => "monthly-plan", "total_price" => %{"deposit" => "45.67"}}
    ]
    |> Enum.each(fn payment_plan ->
      assert {:ok, record} = record_module.from_avro_map(%{"payment_plan" => payment_plan})
      assert {:ok, encoded} = Avrogen.encode_schemaless(record)
      assert {:ok, ^record} = Avrogen.decode_schemaless(record_module, encoded)
    end)
  end
end
