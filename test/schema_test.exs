defmodule Avrogen.Schema.Test do
  use ExUnit.Case, async: true

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

      assert Avrogen.Schema.external_dependencies(input) == ["foo.Bar"]
    end

    test "finds no deps in enum" do
      input = %{
        "type" => "enum"
      }

      assert Avrogen.Schema.external_dependencies(input) == []
    end

    test "doesn't identify previously defined types as external dependencies (with namespace)" do
      input = %{
        "namespace" => "internal",
        "type" => "record",
        "fields" => [
          %{
            "name" => "foo1",
            "type" => %{
              "name" => "Foo",
              "type" => "enum",
              "symbols" => ["A", "B"]
            }
          },
          %{
            "name" => "foo2",
            "type" => "internal.Foo"
          },
          %{
            "name" => "foo3",
            "type" => ["null", "internal.Foo"]
          },
          %{
            "name" => "bar1",
            "type" => "external.Bar"
          },
          %{
            "name" => "bar2",
            "type" => ["null", "external.Bar"]
          }
        ]
      }

      assert Avrogen.Schema.external_dependencies(input) == ["external.Bar"]
    end

    test "doesn't identify previously defined types as external dependencies (without namespace)" do
      input = %{
        "type" => "record",
        "fields" => [
          %{
            "name" => "foo1",
            "type" => %{
              "name" => "Foo",
              "type" => "enum",
              "symbols" => ["A", "B"]
            }
          },
          %{
            "name" => "foo2",
            "type" => "Foo"
          },
          %{
            "name" => "foo3",
            "type" => ["null", "Foo"]
          },
          %{
            "name" => "bar1",
            "type" => "Bar"
          },
          %{
            "name" => "bar2",
            "type" => ["null", "Bar"]
          }
        ]
      }

      assert Avrogen.Schema.external_dependencies(input) == ["Bar"]
    end
  end

  describe "fqn" do
    test "finds fqn in record" do
      input = %{
        "name" => "Foo",
        "namespace" => "bar.baz",
        "type" => "record"
      }

      assert Avrogen.Schema.fqn(input) == "bar.baz.Foo"
    end

    test "finds fqn in enum" do
      input = %{
        "name" => "Foo",
        "namespace" => "bar.baz",
        "type" => "enum"
      }

      assert Avrogen.Schema.fqn(input) == "bar.baz.Foo"
    end

    test "finds fqn in record with no namespace" do
      input = %{
        "name" => "Foo",
        "type" => "enum"
      }

      assert Avrogen.Schema.fqn(input) == "Foo"
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

      assert {:ok, ^expected} = Avrogen.Schema.topological_sort(input)
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

      assert {:error, _} = Avrogen.Schema.topological_sort(input)
    end
  end

  describe "path_from_fqn" do
    test "flat mode" do
      assert Avrogen.Schema.path_from_fqn("some/path", "namespace.Name", :flat) ==
               "some/path/namespace.Name.avsc"
    end

    test "tree mode" do
      assert Avrogen.Schema.path_from_fqn("some/path", "namespace.Name", :tree) ==
               "some/path/namespace/Name.avsc"

      assert Avrogen.Schema.path_from_fqn("some/path", "name.space.Name", :tree) ==
               "some/path/name/space/Name.avsc"
    end
  end
end
