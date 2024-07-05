defmodule Avrogen.CodeGenerator.Test do
  use ExUnit.Case, async: true

  alias Avrogen.Avro.Schema
  alias Avrogen.Avro.Schema.CodeGenerator
  alias Avrogen.Avro.Types

  @schema_file "test/example_schemas.json"

  describe "Generating a record module" do
    test "externalise_inlined_types: at top-level" do
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
            },
            %{
              name: :fraction,
              type: %{
                name: :fraction,
                type: :record,
                fields: [
                  %{name: :numerator, type: :int},
                  %{name: :denominator, type: :int}
                ]
              }
            }
          ]
        })

      assert Schema.normalized_schemas(schema, "parent_namespace", false) ==
               [
                 %Types.Record{
                   name: "Foo",
                   fields: [
                     %Types.Record.Field{
                       name: "unit",
                       type: %Types.Reference{name: "application_data.v2.Unit"}
                     },
                     %Types.Record.Field{
                       name: "fraction",
                       type: %Types.Reference{name: "application_data.v2.Fraction"}
                     }
                   ],
                   namespace: "application_data.v2",
                   type: "record"
                 },
                 %Types.Record{
                   name: "Fraction",
                   fields: [
                     %Types.Record.Field{name: "numerator", type: %Types.Primitive{type: :int}},
                     %Types.Record.Field{name: "denominator", type: %Types.Primitive{type: :int}}
                   ],
                   namespace: "application_data.v2",
                   type: "record"
                 },
                 %Types.Enum{
                   name: "Unit",
                   default: "years",
                   namespace: "application_data.v2",
                   symbols: ["years", "months", "miles"],
                   type: "enum"
                 }
               ]
    end

    test "externalise_inlined_types: in union" do
      schema =
        ensure_string_keys(%{
          type: :record,
          name: "Foo",
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
                },
                %{
                  name: :fraction,
                  type: :record,
                  fields: [
                    %{name: :numerator, type: :int},
                    %{name: :denominator, type: :int}
                  ]
                }
              ]
            }
          ]
        })

      assert Schema.normalized_schemas(schema, "parent_namespace", false) ==
               [
                 %Types.Record{
                   name: "Foo",
                   fields: [
                     %Types.Record.Field{
                       name: "unit",
                       type: %Types.Union{
                         types: [
                           %Types.Primitive{type: :null},
                           %Types.Reference{name: "parent_namespace.Unit"},
                           %Types.Reference{name: "parent_namespace.Fraction"}
                         ]
                       }
                     }
                   ],
                   namespace: "parent_namespace",
                   type: "record"
                 },
                 %Types.Record{
                   name: "Fraction",
                   fields: [
                     %Types.Record.Field{name: "numerator", type: %Types.Primitive{type: :int}},
                     %Types.Record.Field{name: "denominator", type: %Types.Primitive{type: :int}}
                   ],
                   namespace: "parent_namespace",
                   type: "record"
                 },
                 %Types.Enum{
                   name: "Unit",
                   default: "years",
                   namespace: "parent_namespace",
                   symbols: ["years", "months", "miles"],
                   type: "enum"
                 }
               ]
    end

    test "externalise_inlined_types: array in union" do
      schema =
        ensure_string_keys(%{
          type: :record,
          name: "Foo",
          namespace: "application_data.v2",
          fields: [
            %{
              name: :name,
              type: [
                :null,
                %{
                  name: :units,
                  type: :array,
                  items: %{
                    name: :unit,
                    type: :enum,
                    symbols: [:years, :months, :miles],
                    default: :years
                  }
                },
                %{
                  name: :fractions,
                  type: :array,
                  items: %{
                    name: :fraction,
                    type: :record,
                    fields: [
                      %{name: :numerator, type: :int},
                      %{name: :denominator, type: :int}
                    ]
                  }
                }
              ]
            }
          ]
        })

      assert Schema.normalized_schemas(schema, "parent_namespace", false) ==
               [
                 %Types.Record{
                   name: "Foo",
                   fields: [
                     %Types.Record.Field{
                       name: "name",
                       type: %Types.Union{
                         types: [
                           %Types.Primitive{type: :null},
                           %Types.Array{
                             items_schema: %Types.Reference{name: "application_data.v2.Unit"}
                           },
                           %Types.Array{
                             items_schema: %Types.Reference{name: "application_data.v2.Fraction"}
                           }
                         ]
                       }
                     }
                   ],
                   namespace: "application_data.v2",
                   type: "record"
                 },
                 %Types.Record{
                   name: "Fraction",
                   fields: [
                     %Types.Record.Field{name: "numerator", type: %Types.Primitive{type: :int}},
                     %Types.Record.Field{name: "denominator", type: %Types.Primitive{type: :int}}
                   ],
                   namespace: "application_data.v2",
                   type: "record"
                 },
                 %Types.Enum{
                   name: "Unit",
                   default: "years",
                   namespace: "application_data.v2",
                   symbols: ["years", "months", "miles"],
                   type: "enum"
                 }
               ]
    end

    test "externalise_inlined_types: in array" do
      schema =
        ensure_string_keys(%{
          type: :record,
          name: "Foo",
          namespace: "application_data.v2",
          fields: [
            %{
              "name" => "segments",
              "type" => %{
                "items" => %{
                  "fields" => [
                    %{"name" => "starts_at", "type" => "string"}
                  ],
                  "name" => "PolicySegment",
                  "type" => "record"
                },
                "type" => "array"
              }
            }
          ]
        })

      assert Schema.normalized_schemas(schema, "parent_namespace", false) ==
               [
                 %Types.Record{
                   name: "Foo",
                   fields: [
                     %Types.Record.Field{
                       name: "segments",
                       type: %Types.Array{
                         items_schema: %Types.Reference{name: "application_data.v2.PolicySegment"}
                       }
                     }
                   ],
                   namespace: "application_data.v2",
                   type: "record"
                 },
                 %Types.Record{
                   name: "PolicySegment",
                   fields: [
                     %Types.Record.Field{name: "starts_at", type: %Types.Primitive{type: :string}}
                   ],
                   namespace: "application_data.v2",
                   type: "record"
                 }
               ]
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
              name: :union_of_primatives,
              type: [:string, :null]
            },
            %{
              name: :map_type,
              type: %{type: :map, values: :string}
            },
            %{
              name: :union_of_things,
              type: ["application_data.v2.Thingy", "application_data.v2.OtherThing"]
            }
          ]
        })

      assert schema |> Schema.parse() |> Schema.external_dependencies() == [
               "application_data.v2.OtherThing",
               "application_data.v2.Thing",
               "application_data.v2.Thingy"
             ]
    end

    test "elixir type: string" do
      assert "String.t()" ==
               "string"
               |> Schema.parse()
               |> CodeGenerator.elixir_type()
               |> Macro.to_string()
    end

    test "elixir type: map" do
      assert "%{String.t() => Decimal.t()}" ==
               %{"type" => "map", "values" => %{"type" => "string", "logicalType" => "decimal"}}
               |> Schema.parse()
               |> CodeGenerator.elixir_type()
               |> Macro.to_string()
    end

    test "elixir types unions: [null, string]" do
      assert "nil | String.t()" ==
               ["null", "string"]
               |> Schema.parse()
               |> CodeGenerator.elixir_type()
               |> Macro.to_string()
    end

    test "elixir type union: [null, bytes]" do
      assert "nil | binary()" ==
               ["null", "bytes"]
               |> Schema.parse()
               |> CodeGenerator.elixir_type()
               |> Macro.to_string()
    end

    test "elixir type: 'iso_date logical type'" do
      assert "Date.t()" ==
               %{"type" => "string", "logicalType" => "iso_date"}
               |> Schema.parse()
               |> CodeGenerator.elixir_type()
               |> Macro.to_string()
    end

    test "elixir type: 'uuid logical type'" do
      assert "String.t()" ==
               %{"type" => "string", "logicalType" => "uuid"}
               |> Schema.parse()
               |> CodeGenerator.elixir_type()
               |> Macro.to_string()
    end

    test "elixir type: 'timestamp-millis logical type'" do
      assert "DateTime.t()" ==
               %{"type" => "long", "logicalType" => "timestamp-millis"}
               |> Schema.parse()
               |> CodeGenerator.elixir_type()
               |> Macro.to_string()
    end

    test "elixir type: 'timestamp-micros logical type'" do
      assert "DateTime.t()" ==
               %{"type" => "long", "logicalType" => "timestamp-micros"}
               |> Schema.parse()
               |> CodeGenerator.elixir_type()
               |> Macro.to_string()
    end

    test "elixir type: 'date logical type'" do
      assert "Date.t()" ==
               %{"type" => "string", "logicalType" => "date"}
               |> Schema.parse()
               |> CodeGenerator.elixir_type()
               |> Macro.to_string()

      assert "Date.t()" ==
               %{"type" => "int", "logicalType" => "date"}
               |> Schema.parse()
               |> CodeGenerator.elixir_type()
               |> Macro.to_string()
    end

    test "elixir type: 'datetime logical type'" do
      assert "DateTime.t()" ==
               %{"type" => "string", "logicalType" => "datetime"}
               |> Schema.parse()
               |> CodeGenerator.elixir_type()
               |> Macro.to_string()
    end

    test "elixir type: 'time-millis logical type'" do
      assert "Time.t()" ==
               %{"type" => "int", "logicalType" => "time-millis"}
               |> Schema.parse()
               |> CodeGenerator.elixir_type()
               |> Macro.to_string()
    end

    test "elixir type: 'time-micros logical type'" do
      assert "Time.t()" ==
               %{"type" => "long", "logicalType" => "time-micros"}
               |> Schema.parse()
               |> CodeGenerator.elixir_type()
               |> Macro.to_string()
    end

    test "elixir type: 'local-timestamp-millis logical type'" do
      assert "NaiveDateTime.t()" ==
               %{"type" => "long", "logicalType" => "local-timestamp-millis"}
               |> Schema.parse()
               |> CodeGenerator.elixir_type()
               |> Macro.to_string()
    end

    test "elixir type: 'local-timestamp-micros logical type'" do
      assert "NaiveDateTime.t()" ==
               %{"type" => "long", "logicalType" => "local-timestamp-micros"}
               |> Schema.parse()
               |> CodeGenerator.elixir_type()
               |> Macro.to_string()
    end

    test "elixir type: 'decimal logical type'" do
      assert "Decimal.t()" ==
               %{"type" => "string", "logicalType" => "decimal"}
               |> Schema.parse()
               |> CodeGenerator.elixir_type()
               |> Macro.to_string()
    end

    test "elixir type: [null, 'iso_date logical type']" do
      assert "nil | Date.t()" ==
               ["null", %{"type" => "string", "logicalType" => "iso_date"}]
               |> Schema.parse()
               |> CodeGenerator.elixir_type()
               |> Macro.to_string()
    end
  end

  describe "random_instance_field" do
    test "handling maps" do
      map_type = %{
        "type" => "map",
        "values" => %{"logicalType" => "decimal", "type" => "string"}
      }

      assert ~s'Constructors.map(Constructors.decimal())' ==
               map_type
               |> Schema.parse()
               |> CodeGenerator.random_instance([], %{})
               |> Macro.to_string()
    end

    test "handling maps, with custom types as values" do
      map_type = %{"type" => "map", "values" => "renewals.events.v1.Price"}

      global = %{
        "renewals.events.v1.Price" => %Types.Record{
          name: "Price",
          fields: [
            %Types.Record.Field{
              name: "monthly",
              type: ["null", "renewals.events.v1.MonthlyPrice"]
            }
          ],
          namespace: "renewals.events.v1"
        }
      }

      assert ~s'Constructors.map(&Price.random_instance/1)' ==
               map_type
               |> Schema.parse()
               |> CodeGenerator.random_instance([], global)
               |> Macro.to_string()
    end
  end

  describe "generate_code" do
    test "Smoke test" do
      @schema_file
      |> File.read!()
      |> Jason.decode!()
      |> Enum.flat_map(&Schema.generate_code(&1, [], "Test", scope_embedded_types: true))
      |> Enum.each(fn {_filename, code} ->
        code = IO.iodata_to_binary(code)
        assert code =~ "defmodule"
      end)
    end
  end

  def ensure_string_keys(%{} = m) do
    m
    |> Jason.encode!()
    |> Jason.decode!()
  end
end
