defmodule Avro.Types.Test do
  use ExUnit.Case

  describe "external_dependencies" do
    test "finds deps in simple types" do
      assert Avro.Types.external_dependencies("foo.Bar") == ["foo.Bar"]
      assert Avro.Types.external_dependencies("boolean") == []
    end

    test "finds deps in union types" do
      assert Avro.Types.external_dependencies(["foo.Bar", "baz.Qux"]) == ["foo.Bar", "baz.Qux"]
      assert Avro.Types.external_dependencies(["foo.Bar", "int"]) == ["foo.Bar"]
    end

    test "finds deps in array types" do
      assert Avro.Types.external_dependencies(%{"type" => "array", "items" => "foo.Bar"}) == [
               "foo.Bar"
             ]

      assert Avro.Types.external_dependencies(%{"type" => "array", "items" => "string"}) == []

      assert Avro.Types.external_dependencies(%{
               "type" => "array",
               "items" => ["foo.Bar", "baz.Qux"]
             }) == ["foo.Bar", "baz.Qux"]

      assert Avro.Types.external_dependencies(%{"type" => "array", "items" => ["foo.Bar", "null"]}) ==
               ["foo.Bar"]
    end
  end

  describe "is_primitive?" do
    test "detects primitive type in logicalType type" do
      assert Avro.Types.is_primitive?(%{"logicalType" => "foo", "type" => "string"})
    end
  end
end
