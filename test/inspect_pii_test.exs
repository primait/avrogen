defmodule Avrogen.Test.InspectPii do
  use ExUnit.Case, async: false

  alias Avrogen.Avro.Schema

  @schema_file "test/roundtrip_schemas/PersonWithPii.avsc"

  setup_all do
    Code.put_compiler_option(:ignore_already_consolidated, true)
    Code.put_compiler_option(:ignore_module_conflict, true)
    Code.put_compiler_option(:no_warn_undefined, :all)

    schema = File.read!(@schema_file)

    modules =
      schema
      |> Jason.decode!()
      |> Schema.generate_code([], "Test")
      |> Enum.map(&elem(&1, 1))
      |> Enum.map(&IO.iodata_to_binary/1)
      |> Enum.flat_map(&Code.compile_string/1)
      |> Enum.map(&elem(&1, 0))

    record_module =
      Enum.find(modules, fn mod ->
        Code.ensure_loaded?(mod) and function_exported?(mod, :pii_fields, 0)
      end)

    %{record_module: record_module}
  end

  describe "Inspect protocol for records with PII fields" do
    test "redacts PII fields in inspect output", %{record_module: record_module} do
      struct =
        struct(record_module,
          id: "123",
          full_name: "John Doe",
          email: "john@example.com",
          age: 30
        )

      # Call the generated Inspect impl directly (bypassing consolidated protocol dispatch)
      inspect_impl = Module.concat(Inspect, record_module)
      doc = inspect_impl.inspect(struct, %Inspect.Opts{})
      inspected = doc |> Inspect.Algebra.format(80) |> IO.iodata_to_binary()

      refute inspected =~ "John Doe"
      refute inspected =~ "john@example.com"
      assert inspected =~ "**REDACTED**"
      assert inspected =~ "123"
      assert inspected =~ "30"
    end

    test "PII fields are listed in pii_fields/0", %{record_module: record_module} do
      pii = record_module.pii_fields()

      assert MapSet.member?(pii, "full_name")
      assert MapSet.member?(pii, "email")
      refute MapSet.member?(pii, "id")
      refute MapSet.member?(pii, "age")
    end
  end

  describe "Inspect protocol for records without PII fields" do
    test "no custom Inspect impl is generated" do
      schema = File.read!("test/roundtrip_schemas/TestRecord1.avsc")

      modules =
        schema
        |> Jason.decode!()
        |> Schema.generate_code([], "NoPii")
        |> Enum.map(&elem(&1, 1))
        |> Enum.map(&IO.iodata_to_binary/1)
        |> Enum.flat_map(&Code.compile_string/1)
        |> Enum.map(&elem(&1, 0))

      record_module =
        Enum.find(modules, fn mod ->
          Code.ensure_loaded?(mod) and function_exported?(mod, :pii_fields, 0)
        end)

      inspect_impl = Module.concat(Inspect, record_module)
      refute Code.ensure_loaded?(inspect_impl)
    end
  end
end
