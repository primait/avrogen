defmodule Avrogen.SchemaGenerator do
  alias Avrogen.CodeGenerator

  @doc """
  Generates the avro schemas for a given exs file, and returns a list of the schemas generated.
  """
  @spec generate_avsc_files!(String.t(), String.t(), atom()) :: [String.t()]
  def generate_avsc_files!(exs_file_path, out_dir, schema_resolution_mode) do
    # Execute the exs file
    {{:module, schema_module, _, _}, []} = Code.eval_file(exs_file_path)

    # Execute the code to get a list of schemas
    list_of_schemas =
      schema_module.avro_schema_elixir()
      |> ensure_string_keys!()
      |> CodeGenerator.traverse(%{}, nil, scope_embedded_types?(schema_module))
      |> Enum.map(fn {_name, %{schema: schema}} -> schema end)

    # Create the filename for each schema based on its name
    list_of_schemas
    |> Enum.map(fn schema ->
      output_file_path =
        Avrogen.Schema.path_from_fqn(out_dir, Avrogen.Schema.fqn(schema), schema_resolution_mode)

      {output_file_path, schema}
    end)
    # Write out the file to the output dir
    |> Enum.map(fn {file_path, schema} ->
      File.mkdir_p!(Path.dirname(file_path))
      File.write!(file_path, Jason.encode!(schema, pretty: true))
      file_path
    end)
  end

  defp ensure_string_keys!(map) do
    map
    |> Jason.encode!()
    |> Jason.decode!()
  end

  defp scope_embedded_types?(schema_module) do
    case Kernel.function_exported?(schema_module, :scope_embedded_types?, 0) do
      true -> schema_module.scope_embedded_types?()
      false -> false
    end
  end
end
