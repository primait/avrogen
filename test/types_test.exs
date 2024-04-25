defmodule Avrogen.Types.Test do
  alias Avrogen.Avro.Schema
  alias Avrogen.Avro.Types.Primitive
  use ExUnit.Case, async: true

  describe "external_dependencies" do
    test "finds deps in simple types" do
      assert Avrogen.Types.external_dependencies("foo.Bar") == ["foo.Bar"]
      assert Avrogen.Types.external_dependencies("boolean") == []

      assert ["foo.bar"] ==
               "foo.bar"
               |> Schema.parse()
               |> Schema.CodeGenerator.external_dependencies()

      assert [] ==
               "boolean"
               |> Schema.parse()
               |> Schema.CodeGenerator.external_dependencies()
    end

    test "finds deps in union types" do
      assert Avrogen.Types.external_dependencies(["foo.Bar", "baz.Qux"]) == ["foo.Bar", "baz.Qux"]
      assert Avrogen.Types.external_dependencies(["foo.Bar", "int"]) == ["foo.Bar"]

      assert ["foo.Bar", "baz.Qux"] ==
               ["foo.Bar", "baz.Qux"]
               |> Schema.parse()
               |> Schema.CodeGenerator.external_dependencies()

      assert ["foo.Bar"] ==
               ["foo.Bar", "int"]
               |> Schema.parse()
               |> Schema.CodeGenerator.external_dependencies()
    end

    test "finds deps in array types" do
      assert Avrogen.Types.external_dependencies(%{"type" => "array", "items" => "foo.Bar"}) == [
               "foo.Bar"
             ]

      assert ["foo.Bar"] =
               %{"type" => "array", "items" => "foo.Bar"}
               |> Schema.parse()
               |> Schema.CodeGenerator.external_dependencies()

      assert Avrogen.Types.external_dependencies(%{"type" => "array", "items" => "string"}) == []

      assert [] ==
               %{"type" => "array", "items" => "string"}
               |> Schema.parse()
               |> Schema.CodeGenerator.external_dependencies()

      assert Avrogen.Types.external_dependencies(%{"type" => "array", "items" => "bytes"}) == []

      assert [] ==
               %{"type" => "array", "items" => "bytes"}
               |> Schema.parse()
               |> Schema.CodeGenerator.external_dependencies()

      assert Avrogen.Types.external_dependencies(%{
               "type" => "array",
               "items" => ["foo.Bar", "baz.Qux"]
             }) == ["foo.Bar", "baz.Qux"]

      assert ["foo.Bar", "baz.Qux"] ==
               %{"type" => "array", "items" => ["foo.Bar", "baz.Qux"]}
               |> Schema.parse()
               |> Schema.CodeGenerator.external_dependencies()

      assert Avrogen.Types.external_dependencies(%{
               "type" => "array",
               "items" => ["foo.Bar", "null"]
             }) ==
               ["foo.Bar"]

      assert ["foo.Bar"] =
               %{"type" => "array", "items" => ["foo.Bar", "null"]}
               |> Schema.parse()
               |> Schema.CodeGenerator.external_dependencies()
    end
  end

  describe "is_primitive?" do
    test "detects primitive type in logicalType type" do
      assert Avrogen.Types.is_primitive?(%{"logicalType" => "foo", "type" => "string"})
      assert Avrogen.Types.is_primitive?(%{"logicalType" => "foo", "type" => "bytes"})
    end
  end

  describe "primitive" do
    test "parse" do
      Enum.each(
        [
          "null",
          "boolean",
          "int",
          "long",
          "float",
          "double",
          "bytes",
          "string"
        ],
        fn type -> assert %Primitive{type: String.to_atom(type)} == Primitive.parse(type) end
      )

      assert_raise FunctionClauseError, fn -> Primitive.parse("unknown") end
    end
  end

  @schema_file "test/example_schemas.json"
  test "schema parse" do
    @schema_file
    |> File.read!()
    |> Jason.decode!()
    |> Enum.each(fn schema ->
      Schema.parse(schema)
    end)
  end

  test "normalize parse" do
    @schema_file
    |> File.read!()
    |> Jason.decode!()
    |> Enum.each(fn schema ->
      Schema.parse(schema) |> Schema.CodeGenerator.normalize(%{}, nil, true)
    end)

    @schema_file
    |> File.read!()
    |> Jason.decode!()
    |> Schema.parse()
    |> Schema.CodeGenerator.normalize(%{}, nil, true)
  end
end
