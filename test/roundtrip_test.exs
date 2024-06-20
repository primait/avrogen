defmodule Avrogen.Test.Roundtrip do
  @moduledoc """
  Simple roundtrip test.

  Doesn't work for .avsc files with nested record types (yet?).
  """
  use ExUnit.Case, async: true

  alias Avrogen.Avro.Schema
  alias Avrogen.Schema.SchemaRegistry

  @schemas_dir "test/roundtrip_schemas"

  setup_all do
    # Shut up warnings
    Code.put_compiler_option(:ignore_already_consolidated, true)
    Code.put_compiler_option(:ignore_module_conflict, true)
    Code.put_compiler_option(:no_warn_undefined, :all)
  end

  @schemas_dir
  |> File.ls!()
  |> Enum.map(fn schema_path ->
    test "roundtrip #{schema_path}" do
      schema = File.read!(Path.join(@schemas_dir, unquote(schema_path)))

      schema
      |> generate_code()
      |> Enum.map(&compile_code/1)
      |> Enum.map(&module_name/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&check_roundtrip(&1, schema))
    end
  end)

  # Gets the module name of the record type generated code
  defp module_name([_, {mod_name, _}]), do: mod_name
  defp module_name(_), do: nil

  defp check_roundtrip(mod_name, schema) do
    rand_state = :rand.seed(:default)
    {_rand_state, random_instance} = mod_name.random_instance(rand_state)
    encoder = SchemaRegistry.make_encoder(schema)
    decoder = SchemaRegistry.make_decoder(schema)

    encoded = encoder.(mod_name.avro_fqn(), mod_name.to_avro_map(random_instance))
    {:ok, decoded} = decoder.(mod_name.avro_fqn(), encoded) |> mod_name.from_avro_map()

    assert random_instance == decoded
  end

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
