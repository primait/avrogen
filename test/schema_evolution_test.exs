defmodule Avrogen.SchemaEvolution.Test do
  @moduledoc """
  Tests to showcase the limitations of schema evolution using Avrogen.

  Avro binary doesn't contain record names, so each version of the schema lives in its own
  namespace (and so its own generated module) while still being encoded and decoded through the
  same registry.
  """

  use ExUnit.Case, async: false

  alias Avrogen.Schema.SchemaRegistry
  alias Avrogen.Test.SchemaHelpers

  @string_field %{"name" => "string_field", "type" => "string"}

  defp record_schema(namespace, extra_fields) do
    %{
      "type" => "record",
      "name" => "RecordWithString",
      "namespace" => namespace,
      "fields" => [@string_field | extra_fields]
    }
  end

  setup_all do
    Code.put_compiler_option(:ignore_already_consolidated, true)

    schemas = %{
      basic: record_schema("record_basic", []),
      # adds a new field marked as nullable, but with no default
      evolved_incomp:
        record_schema("record_evolved_incomp", [
          %{"name" => "new_field", "type" => ["null", "string"]}
        ]),
      # gives the new field a default of null as well
      evolved_comp:
        record_schema("record_evolved_comp", [
          %{"name" => "new_field", "type" => ["null", "string"], "default" => nil}
        ])
    }

    modules =
      Map.new(schemas, fn {version, schema} ->
        fqn = "#{schema["namespace"]}.#{schema["name"]}"

        module =
          schema
          |> Jason.encode!()
          |> SchemaHelpers.generate_modules_from_schema()
          |> Enum.find(&(&1.avro_fqn() == fqn))

        {version, module}
      end)

    registry_avsc = schemas |> Map.values() |> Jason.encode!()

    :ets.new(SchemaRegistry, [:set, :protected, :named_table])

    :ets.insert(
      SchemaRegistry,
      {"all", registry_avsc, SchemaRegistry.make_encoder(registry_avsc),
       SchemaRegistry.make_decoder(registry_avsc)}
    )

    modules
  end

  test "basic evolution of adding a nullable field", modules do
    basic = struct(modules.basic, string_field: "mr")
    evolved_comp = struct(modules.evolved_comp, string_field: "mr", new_field: nil)
    evolved_incomp = struct(modules.evolved_incomp, string_field: "mr", new_field: nil)

    # 1) basic data roundtripped with basic schema is unchanged
    assert {:ok, bytes} = Avrogen.encode_schemaless(basic)
    assert {:ok, ^basic} = Avrogen.decode_schemaless(modules.basic, bytes)

    # 2) data roundtripped with either evolved schema is unchanged, with the new field null
    for {module, record} <- [
          {modules.evolved_comp, evolved_comp},
          {modules.evolved_incomp, evolved_incomp}
        ] do
      assert {:ok, bytes} = Avrogen.encode_schemaless(record)
      assert {:ok, ^record} = Avrogen.decode_schemaless(module, bytes)
    end

    # 3) the generated modules don't apply the schema's default: old-shaped data is rejected by
    # from_avro_map even when the new field has a default of null
    for module <- [modules.evolved_comp, modules.evolved_incomp] do
      assert {:error, "Missing keys: new_field"} =
               module.from_avro_map(%{"string_field" => "mr"})
    end

    # 4) bytes encoded by the basic schema are NOT decodable by either evolved schema :(
    {:ok, basic_bytes} = Avrogen.encode_schemaless(basic)

    for module <- [modules.evolved_comp, modules.evolved_incomp] do
      assert {:error, message} = Avrogen.decode_schemaless(module, basic_bytes)
      assert message =~ "MatchError"
    end
  end

  test "base64 encoded avro bytes are incompatible across versions", modules do
    basic = struct(modules.basic, string_field: "mr")
    {:ok, b64} = Avrogen.encode_schemaless_base64(basic)

    assert {:ok, ^basic} = Avrogen.decode_schemaless_base64(modules.basic, b64)

    for module <- [modules.evolved_comp, modules.evolved_incomp] do
      assert {:error, message} = Avrogen.decode_schemaless_base64(module, b64)
      assert message =~ "MatchError"
    end
  end

  test "old bytes can be read by decoding with the old schema and upgrading the result",
       modules do
    {:ok, b64} = Avrogen.encode_schemaless_base64(struct(modules.basic, string_field: "mr"))

    assert {:ok, old} = Avrogen.decode_schemaless_base64(modules.basic, b64)

    assert {:ok, upgraded} =
             old
             |> modules.basic.to_avro_map()
             |> Map.put("new_field", nil)
             |> modules.evolved_comp.from_avro_map()

    assert upgraded == struct(modules.evolved_comp, string_field: "mr", new_field: nil)

    # and the upgraded record is now readable with the new schema
    assert {:ok, new_b64} = Avrogen.encode_schemaless_base64(upgraded)
    assert {:ok, ^upgraded} = Avrogen.decode_schemaless_base64(modules.evolved_comp, new_b64)
  end
end
