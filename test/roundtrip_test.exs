defmodule Avrogen.Test.Roundtrip do
  @moduledoc """
  Simple roundtrip test.

  Doesn't work for .avsc files with nested record types (yet?).
  """
  use ExUnit.Case, async: true

  alias Avrogen.CodeGenerator
  alias Avrogen.Schema.SchemaRegistry

  @schemas_dir "test/roundtrip_schemas"

  defp swap({a, b}), do: {b, a}

  test "roundtrip" do
    # Read all schemas from the @schemas_dir
    schemas =
      @schemas_dir
      |> File.ls!()
      |> Enum.map(&File.read!(Path.join(@schemas_dir, &1)))

    # Generate and compile code for each example schema.
    # This produces a list of compiled module names like
    # [
    #   Test.RecordWithBytes.RecordWithBytes,
    #   Test.Events.V1.MidTermAdjustmentOfferFeesOverriden,
    #   ...
    # ]
    mod_names =
      schemas
      |> Enum.map(fn schema ->
        schema
        |> Jason.decode!()
        |> CodeGenerator.generate_schema([], "Test", scope_embedded_types: true)
        |> Enum.map(fn {_filename, code} ->
          # Shut up warnings
          Code.put_compiler_option(:ignore_already_consolidated, true)
          compiled_code = Code.compile_string(code)
          mod_name = compiled_code |> tl() |> hd() |> elem(0)
          mod_name
        end)
      end)
      |> List.flatten()

    # For each schema module, generate a random instance of the schema.
    initial_rand_state = :rand.seed(:default)

    {random_instances, _final_rand_state} =
      mod_names
      |> Enum.map_reduce(initial_rand_state, fn mod_name, rand_state ->
        mod_name.random_instance(rand_state) |> swap()
      end)

    # Check that each random instance roundtrips correctly.
    Enum.zip([mod_names, schemas, random_instances])
    |> Enum.map(fn {mod_name, schema, random_instance} ->
      encoder = SchemaRegistry.make_encoder(schema)
      decoder = SchemaRegistry.make_decoder(schema)

      encoded = encoder.(mod_name.avro_fqn(), mod_name.to_avro_map(random_instance))
      {:ok, decoded} = decoder.(mod_name.avro_fqn(), encoded) |> mod_name.from_avro_map()

      assert random_instance == decoded
    end)
  end
end
