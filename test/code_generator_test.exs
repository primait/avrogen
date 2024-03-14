defmodule Avrogen.CodeGenerator.Test do
  use ExUnit.Case, async: true

  alias Avrogen.CodeGenerator

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

      assert CodeGenerator.externalise_inlined_types(schema["fields"], %{}, "parent_namespace") ==
               {
                 [
                   %{"name" => "unit", "type" => "parent_namespace.Unit"},
                   %{"name" => "fraction", "type" => "parent_namespace.Fraction"}
                 ],
                 %{
                   "parent_namespace.Unit" => %{
                     name: "Unit",
                     schema: %{
                       "default" => "years",
                       "name" => "unit",
                       "namespace" => "parent_namespace",
                       "symbols" => ["years", "months", "miles"],
                       "type" => "enum"
                     },
                     type: :enum
                   },
                   "parent_namespace.Fraction" => %{
                     name: "Fraction",
                     type: :record,
                     schema: %{
                       "fields" => [
                         %{"name" => "numerator", "type" => "int"},
                         %{"name" => "denominator", "type" => "int"}
                       ],
                       "name" => "fraction",
                       "namespace" => "parent_namespace",
                       "type" => "record"
                     }
                   }
                 }
               }
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

      assert CodeGenerator.externalise_inlined_types(schema["fields"], %{}, "parent_namespace") ==
               {
                 [
                   %{
                     "name" => "unit",
                     "type" => ["null", "parent_namespace.Unit", "parent_namespace.Fraction"]
                   }
                 ],
                 %{
                   "parent_namespace.Unit" => %{
                     name: "Unit",
                     schema: %{
                       "default" => "years",
                       "name" => "unit",
                       "namespace" => "parent_namespace",
                       "symbols" => ["years", "months", "miles"],
                       "type" => "enum"
                     },
                     type: :enum
                   },
                   "parent_namespace.Fraction" => %{
                     name: "Fraction",
                     schema: %{
                       "fields" => [
                         %{"name" => "numerator", "type" => "int"},
                         %{"name" => "denominator", "type" => "int"}
                       ],
                       "name" => "fraction",
                       "namespace" => "parent_namespace",
                       "type" => "record"
                     },
                     type: :record
                   }
                 }
               }
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

      assert CodeGenerator.externalise_inlined_types(schema["fields"], %{}, "parent_namespace") ==
               {
                 [
                   %{
                     "name" => "name",
                     "type" => [
                       "null",
                       %{
                         "type" => "array",
                         "name" => "units",
                         "items" => "parent_namespace.Unit"
                       },
                       %{
                         "type" => "array",
                         "name" => "fractions",
                         "items" => "parent_namespace.Fraction"
                       }
                     ]
                   }
                 ],
                 %{
                   "parent_namespace.Unit" => %{
                     name: "Unit",
                     schema: %{
                       "default" => "years",
                       "name" => "unit",
                       "namespace" => "parent_namespace",
                       "symbols" => ["years", "months", "miles"],
                       "type" => "enum"
                     },
                     type: :enum
                   },
                   "parent_namespace.Fraction" => %{
                     name: "Fraction",
                     schema: %{
                       "fields" => [
                         %{"name" => "numerator", "type" => "int"},
                         %{"name" => "denominator", "type" => "int"}
                       ],
                       "name" => "fraction",
                       "namespace" => "parent_namespace",
                       "type" => "record"
                     },
                     type: :record
                   }
                 }
               }
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

      assert CodeGenerator.externalise_inlined_types(schema["fields"], %{}, "parent_namespace") ==
               {
                 [
                   %{
                     "name" => "segments",
                     "type" => %{"type" => "array", "items" => "parent_namespace.PolicySegment"}
                   }
                 ],
                 %{
                   "parent_namespace.PolicySegment" => %{
                     name: "PolicySegment",
                     schema: %{
                       "name" => "PolicySegment",
                       "namespace" => "parent_namespace",
                       "fields" => [%{"name" => "starts_at", "type" => "string"}],
                       "type" => "record"
                     },
                     type: :record
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

    test "typedstruct_field: map" do
      assert "field :field_name, %{String.t() => Decimal.t()}, enforce: true" ==
               CodeGenerator.typedstruct_field(%{
                 "name" => "field_name",
                 "type" => %{
                   "type" => "map",
                   "values" => %{"type" => "string", "logicalType" => "decimal"}
                 }
               })
    end

    test "typedstruct_field: [null, string]" do
      assert "field :field_name, nil | String.t()" ==
               CodeGenerator.typedstruct_field(%{
                 "name" => "field_name",
                 "type" => ["null", "string"]
               })
    end

    test "typedstruct_field: [null, bytes]" do
      assert "field :field_name, nil | binary()" ==
               CodeGenerator.typedstruct_field(%{
                 "name" => "field_name",
                 "type" => ["null", "bytes"]
               })
    end

    test "typedstruct_field: 'iso_date logical type'" do
      assert "field :field_name, Date.t(), enforce: true" ==
               CodeGenerator.typedstruct_field(%{
                 "name" => "field_name",
                 "type" => [%{"type" => "string", "logicalType" => "iso_date"}]
               })
    end

    test "typedstruct_field: 'date logical type'" do
      assert "field :field_name, Date.t(), enforce: true" ==
               CodeGenerator.typedstruct_field(%{
                 "name" => "field_name",
                 "type" => [%{"type" => "string", "logicalType" => "date"}]
               })
    end

    test "typedstruct_field: 'decimal logical type'" do
      assert "field :field_name, Decimal.t(), enforce: true" ==
               CodeGenerator.typedstruct_field(%{
                 "name" => "field_name",
                 "type" => [%{"type" => "string", "logicalType" => "decimal"}]
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

  describe "from_avro_map_main_clause" do
    test "with no optional fields" do
      fields = [
        %{"name" => "first_name", "type" => "string"},
        %{"name" => "surname", "type" => "string"},
        %{"name" => "email", "type" => ["null", "string"]}
      ]

      assert """
             @impl true
             def from_avro_map(%{
               "first_name" => first_name,
               "surname" => surname,
               "email" => email
             }) do
               
               {:ok, %__MODULE__{
                 first_name: first_name,
                 surname: surname,
                 email: email
               }}
             end
             """ == CodeGenerator.from_avro_map_main_clause(fields, %{})
    end

    test "with optional fields" do
      fields = [
        %{"name" => "first_name", "type" => "string"},
        %{"name" => "surname", "type" => "string"},
        %{"name" => "email", "type" => ["null", "string"], "default" => "null"},
        %{"name" => "optin", "type" => "boolean", "default" => true}
      ]

      assert """
             @impl true
             def from_avro_map(%{
               "first_name" => first_name,
               "surname" => surname
             } = avro_map) do
               email = avro_map["email"]
               optin = avro_map["optin"] || true
               {:ok, %__MODULE__{
                 first_name: first_name,
                 surname: surname,
                 email: email,
                 optin: optin
               }}
             end
             """ == CodeGenerator.from_avro_map_main_clause(fields, %{})
    end
  end

  describe "to_avro_map_field" do
    test "handling maps" do
      map_type = %{
        "name" => "premium_breakdown",
        "type" => %{
          "type" => "map",
          "values" => %{"logicalType" => "decimal", "type" => "string"}
        }
      }

      assert ~s'"premium_breakdown" => Enum.into(r.premium_breakdown, %{}, fn {k, v} -> {k, Decimal.to_string(v)} end)' ==
               CodeGenerator.to_avro_map_field(map_type, %{})
    end

    test "decimal types" do
      decimal_type = %{
        "name" => "price",
        "type" => ["null", %{"type" => "string", "logicalType" => "decimal"}]
      }

      assert ~s'"price" => case r.price do\n %Decimal{} = d -> Decimal.to_string(d)\n_ -> r.price\nend' ==
               CodeGenerator.to_avro_map_field(decimal_type, %{})
    end
  end

  describe "from_avro_map_body_field" do
    test "handling maps" do
      map_type = %{
        "name" => "premium_breakdown",
        "type" => %{
          "type" => "map",
          "values" => %{"logicalType" => "decimal", "type" => "string"}
        }
      }

      assert ~s'premium_breakdown: Enum.into(premium_breakdown, %{}, fn {k, v} -> {k, Decimal.new(v)} end)' ==
               CodeGenerator.from_avro_map_body_field(map_type, %{})
    end

    test "decimal types" do
      decimal_type = %{
        "name" => "price",
        "type" => ["null", %{"type" => "string", "logicalType" => "decimal"}]
      }

      assert ~s'price: if not is_nil(price) and (Decimal.parse(price) != :error) do\n  Decimal.new(price)\nelse\n  price\nend' ==
               CodeGenerator.from_avro_map_body_field(decimal_type, %{})
    end

    test "date types" do
      decimal_type = %{
        "name" => "price",
        "type" => ["null", %{"type" => "string", "logicalType" => "date"}]
      }

      assert ~s'price: if is_binary(price) and ( Date.from_iso8601(price) |> elem(0) == :ok) do\n  Date.from_iso8601(price) |> elem(1)\nelse\n  price\nend' ==
               CodeGenerator.from_avro_map_body_field(decimal_type, %{})
    end

    test "datetime types" do
      decimal_type = %{
        "name" => "price",
        "type" => ["null", %{"type" => "string", "logicalType" => "datetime"}]
      }

      assert ~s'price: if is_binary(price) and ( DateTime.from_iso8601(price) |> elem(0) == :ok) do\n  DateTime.from_iso8601(price) |> elem(1)\nelse\n  price\nend' ==
               CodeGenerator.from_avro_map_body_field(decimal_type, %{})
    end
  end

  describe "random_instance_field" do
    test "handling maps" do
      map_type = %{
        "name" => "premium_breakdown",
        "type" => %{
          "type" => "map",
          "values" => %{"logicalType" => "decimal", "type" => "string"}
        }
      }

      assert ~s'Avrogen.Util.Random.Constructors.map(Avrogen.Util.Random.Constructors.decimal())' ==
               CodeGenerator.random_instance_field(map_type, %{})
    end

    test "handling maps, with custom types as values" do
      map_type = %{
        "name" => "premium_breakdown",
        "type" => %{
          "type" => "map",
          "values" => "renewals.events.v1.Price"
        }
      }

      assert ~s'Avrogen.Util.Random.Constructors.map(fn rand_state -> Price.random_instance(rand_state) end)' ==
               CodeGenerator.random_instance_field(map_type, %{
                 "renewals.events.v1.Price" => %{
                   name: "Price",
                   referenced_schemas: ["renewals.events.v1.MonthlyPrice"],
                   schema: %{
                     "fields" => [
                       %{
                         "doc" => "The total cost when paying annually",
                         "logicalType" => "decimal",
                         "name" => "annual",
                         "type" => "string"
                       },
                       %{
                         "doc" => "The monthly payment plan details",
                         "name" => "monthly",
                         "type" => ["null", "renewals.events.v1.MonthlyPrice"]
                       }
                     ],
                     "name" => "Price",
                     "namespace" => "renewals.events.v1",
                     "type" => "record"
                   },
                   type: :record
                 }
               })
    end
  end

  describe "generate_schema" do
    test "Smoke test" do
      @schema_file
      |> File.read!()
      |> Jason.decode!()
      |> Enum.each(fn schema ->
        CodeGenerator.generate_schema(schema, [], "Test", scope_embedded_types: true)
        |> Enum.each(fn {_filename, code} -> assert code =~ "defmodule" end)
      end)
    end
  end

  def ensure_string_keys(%{} = m) do
    m
    |> Jason.encode!()
    |> Jason.decode!()
  end
end
