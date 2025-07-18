defmodule Avrogen.EnumWithDefaultTest do
  @moduledoc """
  Tests enum default value behavior during schema evolution.
  """
  use ExUnit.Case, async: false

  alias Avrogen.Avro.Schema
  alias Avrogen.Schema.SchemaRegistry

  @schemas_dir "test/enum_default_schemas"

  setup_all do
    # Shut up warnings
    Code.put_compiler_option(:ignore_already_consolidated, true)
    Code.put_compiler_option(:ignore_module_conflict, true)
    Code.put_compiler_option(:no_warn_undefined, :all)
  end

  test "decodes unknown enum symbol to default value" do
    schema_1 = File.read!(Path.join(@schemas_dir, "RecordWithEnumDefault1.avsc"))
    schema_2 = File.read!(Path.join(@schemas_dir, "RecordWithEnumDefault2.avsc"))

    module_1 = generate_module_from_schema(schema_1)
    module_2 = generate_module_from_schema(schema_2)

    encoder = SchemaRegistry.make_encoder(schema_2)
    decoder = SchemaRegistry.make_decoder(schema_1)

    module_2_instance = struct(module_2, source: :external)

    encoded =
      encoder.(
        module_2.avro_fqn(),
        module_2.to_avro_map(module_2_instance)
      )

    assert {:ok, %^module_1{source: :unknown}} =
             decoder.(module_1.avro_fqn(), encoded) |> module_1.from_avro_map()
  end

  defp generate_module_from_schema(schema) do
    schema
    |> generate_code()
    |> Enum.map(&compile_code/1)
    |> Enum.map(&module_name/1)
    |> Enum.reject(&is_nil/1)
    |> List.first()
  end

  # Gets the module name of the record type generated code
  defp module_name([_, {mod_name, _}]), do: mod_name
  defp module_name(_), do: nil

  defp compile_code(code) do
    code
    |> IO.iodata_to_binary()
    |> Code.compile_string()
  end

  defp generate_code(schema) do
    schema
    |> Jason.decode!()
    |> Schema.generate_code([], "Test")
    |> Enum.map(&elem(&1, 1))
  end
end
