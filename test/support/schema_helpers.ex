defmodule Avrogen.Test.SchemaHelpers do
  @moduledoc """
  Common helper functions for testing schema generation and module compilation.
  """

  alias Avrogen.Avro.Schema

  @doc """
  Generates a module from an Avro schema string.

  The schema is parsed, code is generated, compiled, and the resulting module name is returned.
  """
  def generate_module_from_schema(schema) do
    schema
    |> generate_code()
    |> Enum.map(&compile_code/1)
    |> Enum.map(&module_name/1)
    |> Enum.reject(&is_nil/1)
    |> List.first()
  end

  @doc """
  Generates code from an Avro schema string.
  The schema is parsed and code is generated but not compiled.
  """
  def generate_code_from_schema(schema) do
    schema
    |> generate_code()
    |> Enum.map_join("\n", &IO.iodata_to_binary/1)
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
