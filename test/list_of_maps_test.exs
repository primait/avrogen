defmodule Avrogen.MapNoWarningsTest do
  @moduledoc """
  Tests that array fields containing maps with union type values don't generate compilation warnings.

  The warning that was fixed:
  "clauses with the same name and arity (number of arguments) should be grouped together"

  This occurred with schemas like:
  - Field type: array
  - Items: map
  - Map values: union type (e.g., ["null", "string"])

  The fix ensures the main encoding function is defined BEFORE its helper functions,
  so that all helper function clauses are properly grouped together.
  """
  use ExUnit.Case, async: false

  alias Avrogen.Test.SchemaHelpers

  @schemas_dir "test/list_of_maps_schemas"

  describe "map encode function" do
    test "compiles without clause grouping warnings" do
      schema = File.read!(Path.join(@schemas_dir, "ListOfMaps.avsc"))

      # Generate code
      generated_code = SchemaHelpers.generate_code_from_schema(schema)

      # Compile with diagnostics to capture warnings
      {_result, diagnostics} =
        Code.with_diagnostics(fn -> Code.compile_string(generated_code) end)

      # Check for clause grouping warnings
      clause_warnings =
        Enum.filter(diagnostics, fn diagnostic ->
          String.contains?(
            diagnostic.message,
            "clauses with the same name and arity (number of arguments) should be grouped together,"
          )
        end)

      assert clause_warnings == [],
             "Expected no clause grouping warnings, but got:\n#{inspect(clause_warnings, pretty: true)}"
    end
  end
end
