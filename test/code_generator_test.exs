defmodule Avro.CodeGenerator.Test do
  use ExUnit.Case

  alias Avro.CodeGenerator

  describe "Generating a record module" do
    test "externalise_inlined_enums: at top-level" do
      schema =
        ensure_string_keys(%{
          type: :record,
          name: "Foo",
          namespace: "application_data.v2",
          fields: [
            %{
              name: :unit,
              type: %{
                name: :unit,
                type: :enum,
                symbols: [:years, :months, :miles],
                default: :years
              }
            }
          ]
        })

      assert CodeGenerator.externalise_inlined_enums(schema["fields"], %{}, "parent_namespace") ==
               {
                 [
                   %{"name" => "unit", "type" => "parent_namespace.Unit"}
                 ],
                 %{
                   "parent_namespace.Unit" => %{
                     name: "Unit",
                     schema: %{
                       "default" => "years",
                       "name" => "unit",
                       "symbols" => ["years", "months", "miles"],
                       "type" => "enum"
                     },
                     type: :enum
                   }
                 }
               }
    end

    test "externalise_inlined_enums: in union" do
      schema =
        ensure_string_keys(%{
          type: :record,
          name: "Foo",
          namespace: "application_data.v2",
          fields: [
            %{
              name: :unit,
              type: [
                :null,
                %{
                  name: :unit,
                  type: :enum,
                  symbols: [:years, :months, :miles],
                  default: :years
                }
              ]
            }
          ]
        })

      assert CodeGenerator.externalise_inlined_enums(schema["fields"], %{}, "parent_namespace") ==
               {
                 [
                   %{"name" => "unit", "type" => ["null", "parent_namespace.Unit"]}
                 ],
                 %{
                   "parent_namespace.Unit" => %{
                     name: "Unit",
                     schema: %{
                       "default" => "years",
                       "name" => "unit",
                       "symbols" => ["years", "months", "miles"],
                       "type" => "enum"
                     },
                     type: :enum
                   }
                 }
               }
    end

    test "get_references extracts from record fields in alphabetical order direct references, references in unions and in arrays" do
      schema =
        ensure_string_keys(%{
          type: :record,
          name: "Foo",
          namespace: "application_data.v2",
          fields: [
            %{
              name: :thing_1,
              type: "application_data.v2.Thing"
            },
            %{
              name: :thing_2,
              type: [:null, "application_data.v2.OtherThing"]
            },
            %{
              name: :more_things,
              type: %{type: :array, items: "application_data.v2.Thingy"}
            },
            %{
              name: :union_of_things,
              type: ["application_data.v2.Thingy", "application_data.v2.OtherThing"]
            }
          ]
        })

      assert CodeGenerator.get_references(schema) == [
               "application_data.v2.OtherThing",
               "application_data.v2.Thing",
               "application_data.v2.Thingy"
             ]
    end

    test "typedstruct_field: string" do
      assert "field :field_name, String.t(), enforce: true" ==
               CodeGenerator.typedstruct_field(%{"name" => "field_name", "type" => "string"})
    end

    test "typedstruct_field: [null, string]" do
      assert "field :field_name, nil | String.t()" ==
               CodeGenerator.typedstruct_field(%{
                 "name" => "field_name",
                 "type" => ["null", "string"]
               })
    end

    test "typedstruct_field: 'iso_date logical type'" do
      assert "field :field_name, Date.t(), enforce: true" ==
               CodeGenerator.typedstruct_field(%{
                 "name" => "field_name",
                 "type" => [%{"type" => "string", "logicalType" => "iso_date"}]
               })
    end

    test "typedstruct_field: [null, 'iso_date logical type']" do
      assert "field :field_name, nil | Date.t()" ==
               CodeGenerator.typedstruct_field(%{
                 "name" => "field_name",
                 "type" => ["null", %{"type" => "string", "logicalType" => "iso_date"}]
               })
    end
  end

  def ensure_string_keys(%{} = m) do
    m
    |> Jason.encode!()
    |> Jason.decode!()
  end
end
