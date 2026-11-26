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

  describe "base64 variants" do
    setup %{record_module: record_module} do
      {:ok, record} =
        record_module.from_avro_map(%{
          "payment_plan" => %{
            "identifier" => "monthly-plan",
            "total_price" => %{"deposit" => "45.67"}
          }
        })

      %{record: record}
    end

    test "encode_schemaless_base64 is the base64 of the schemaless bytes", %{record: record} do
      {:ok, iodata} = Avrogen.encode_schemaless(record)
      {:ok, b64} = Avrogen.encode_schemaless_base64(record)

      assert Base.decode64!(b64) == IO.iodata_to_binary(iodata)
    end

    test "base64 roundtrip", %{record_module: record_module, record: record} do
      assert {:ok, b64} = Avrogen.encode_schemaless_base64(record)
      assert {:ok, ^record} = Avrogen.decode_schemaless_base64(record_module, b64)
    end

    test "decode_schemaless_base64 rejects invalid base64", %{record_module: record_module} do
      assert {:error, :invalid_base64} =
               Avrogen.decode_schemaless_base64(record_module, "not base64!")
    end

    test "decode_schemaless_base64 returns an error for bytes that don't match the schema", %{
      record_module: record_module
    } do
      assert {:error, message} =
               Avrogen.decode_schemaless_base64(record_module, Base.encode64(<<255, 255, 255>>))

      assert is_binary(message)
    end

    test "encode_schemaless_base64 returns an error for a record that can't be encoded", %{
      record_module: record_module
    } do
      invalid = struct(record_module, payment_plan: :not_a_plan)

      assert {:error, message} = Avrogen.encode_schemaless_base64(invalid)
      assert is_binary(message)
    end
  end
end
