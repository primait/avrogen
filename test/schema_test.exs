defmodule Avro.Schema.Test do
  use ExUnit.Case

  describe "external_dependencies" do
    test "finds deps in simple record" do
      input = %{
        "type" => "record",
        "fields" => [
          %{
            "name" => "foo",
            "type" => "foo.Bar"
          }
        ]
      }

      assert Avro.Schema.external_dependencies(input) == ["foo.Bar"]
    end

    test "finds no deps in enum" do
      input = %{
        "type" => "enum"
      }

      assert Avro.Schema.external_dependencies(input) == []
    end
  end

  describe "fqn" do
    test "finds fqn in record" do
      input = %{
        "name" => "Foo",
        "namespace" => "bar.baz",
        "type" => "record"
      }

      assert Avro.Schema.fqn(input) == "bar.baz.Foo"
    end

    test "finds fqn in enum" do
      input = %{
        "name" => "Foo",
        "namespace" => "bar.baz",
        "type" => "enum"
      }

      assert Avro.Schema.fqn(input) == "bar.baz.Foo"
    end

    test "finds fqn in record with no namespace" do
      input = %{
        "name" => "Foo",
        "type" => "enum"
      }

      assert Avro.Schema.fqn(input) == "Foo"
    end
  end

  describe "topological sort" do
    test "sorts acyclic records" do
      input = [
        %{
          "name" => "Foo",
          "type" => "record",
          "fields" => [
            %{
              "type" => "Bar"
            }
          ]
        },
        %{
          "name" => "Bar",
          "type" => "record",
          "fields" => []
        }
      ]

      expected = [
        %{
          "name" => "Bar",
          "type" => "record",
          "fields" => []
        },
        %{
          "name" => "Foo",
          "type" => "record",
          "fields" => [
            %{
              "type" => "Bar"
            }
          ]
        }
      ]

      assert {:ok, ^expected} = Avro.Schema.topological_sort(input)
    end

    test "errors on cyclic records" do
      input = [
        %{
          "name" => "Foo",
          "type" => "record",
          "fields" => [
            %{
              "type" => "Bar"
            }
          ]
        },
        %{
          "name" => "Bar",
          "type" => "record",
          "fields" => [
            %{
              "type" => "Foo"
            }
          ]
        }
      ]

      assert {:error, _} = Avro.Schema.topological_sort(input)
    end
  end
end
