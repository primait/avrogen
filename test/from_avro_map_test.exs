defmodule Avrogen.FromAvroMapTest do
  @moduledoc """
  Tests enum default value behavior during schema evolution.
  """
  use ExUnit.Case, async: false

  alias Avrogen.Test.SchemaHelpers

  @schemas_dir "test/from_avro_map_schemas"
  setup_all do
    # Shut up warnings
    Code.put_compiler_option(:ignore_already_consolidated, true)
    Code.put_compiler_option(:ignore_module_conflict, true)
    Code.put_compiler_option(:no_warn_undefined, :all)

    :ok
  end

  describe "from_avro_map/1" do
    setup do
      schema = File.read!(Path.join(@schemas_dir, "TestRecord.avsc"))

      module = SchemaHelpers.generate_module_from_schema(schema)

      {:ok, module: module}
    end

    test "returns error when required keys are not present", %{module: module} do
      assert {:error, "Missing keys: required_string"} = module.from_avro_map(%{})
    end

    test "decodes optional and default fields correctly when only required fields are provided",
         %{module: module} do
      assert {:ok,
              %^module{
                required_string: "value",
                opt_string: nil,
                string_with_default: "default_value"
              }} = module.from_avro_map(%{"required_string" => "value"})
    end

    test "decodes all fields correctly when all fields are provided", %{module: module} do
      assert {:ok,
              %^module{
                required_string: "required_value",
                opt_string: "optional_value",
                string_with_default: "custom_value"
              }} =
               module.from_avro_map(%{
                 "required_string" => "required_value",
                 "opt_string" => "optional_value",
                 "string_with_default" => "custom_value"
               })
    end
  end
end
