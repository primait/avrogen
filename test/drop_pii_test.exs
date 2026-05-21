defmodule Avrogen.Test.DropPii do
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
end
