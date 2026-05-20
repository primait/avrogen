defmodule Avrogen.Test.InspectPii do
  use ExUnit.Case, async: false

  alias Avrogen.Avro.Schema

  setup_all do
    Code.put_compiler_option(:ignore_already_consolidated, true)
    Code.put_compiler_option(:ignore_module_conflict, true)
    Code.put_compiler_option(:no_warn_undefined, :all)

    modules =
      "test/pii_schemas/example_schemas_with_pii.json"
      |> File.read!()
      |> Jason.decode!()
      |> Schema.generate_code([], "Test")
      |> Enum.map(&elem(&1, 1))
      |> Enum.map_join("\n", &IO.iodata_to_binary/1)
      |> Code.compile_string()
      |> MapSet.new(&elem(&1, 0))

    expected_modules =
      MapSet.new([
        Test.Events.V1.PersonWithPii,
        Test.Events.V1.PetWithPii,
        Test.Events.V1.Species
      ])

    assert MapSet.subset?(expected_modules, modules)

    %{
      person_module: Test.Events.V1.PersonWithPii,
      pet_module: Test.Events.V1.PetWithPii,
      species_module: Test.Events.V1.Species
    }
  end

  describe "drop_pii replaces values of fields marked with `pii: true` with nil or appropriate value for type" do
    test "basic record case", %{pet_module: pet_module, species_module: species_module} do
      pet = struct(pet_module, name: "Roger", vet_name: "Mike", species: species_module._cat())
      dropped = pet_module.drop_pii(pet)

      assert dropped ==
               struct(pet_module, name: "", vet_name: nil, species: species_module._cat())
    end

    test "array case", %{
      person_module: person_module,
      pet_module: pet_module,
      species_module: species_module
    } do
      person =
        struct(person_module,
          id: "123",
          full_name: "Brian Smithson",
          email: "bribri@smithson.org",
          age: 45,
          address_lines: ["1 Marrow Lane", "Preston"],
          pets: [
            struct(pet_module, name: "Roger", vet_name: "Mike", species: species_module._cat())
          ]
        )

      dropped = person_module.drop_pii(person)

      assert dropped ==
               struct(person_module,
                 id: "123",
                 full_name: nil,
                 email: nil,
                 age: 45,
                 address_lines: [],
                 pets: [
                   struct(pet_module,
                     name: "",
                     vet_name: nil,
                     species: species_module._cat()
                   )
                 ]
               )
    end
  end

  describe "Inspect protocol for records with PII fields" do
    test "redacts PII fields in inspect output", %{person_module: record_module} do
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

    test "PII fields are listed in pii_fields/0", %{person_module: record_module} do
      pii = record_module.pii_fields()

      assert MapSet.member?(pii, "full_name")
      assert MapSet.member?(pii, "email")
      assert MapSet.member?(pii, "address_lines")
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
