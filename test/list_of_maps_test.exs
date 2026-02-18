defmodule Avrogen.ListOfMapsTest do
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

      generated_code = SchemaHelpers.generate_code_from_schema(schema)

      # Compile and capture warnings
      warnings =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          Code.compile_string(generated_code)
        end)

      # Check for clause grouping warnings
      refute String.contains?(
               warnings,
               "clauses with the same name and arity (number of arguments) should be grouped together"
             ),
             "Expected no clause grouping warnings, but got:\n#{warnings}"
    end
  end
end
