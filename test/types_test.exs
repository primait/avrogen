defmodule Avrogen.Types.Test do
  use ExUnit.Case, async: true

  describe "external_dependencies" do
    test "finds deps in simple types" do
      assert Avrogen.Types.external_dependencies("foo.Bar") == ["foo.Bar"]
      assert Avrogen.Types.external_dependencies("boolean") == []
    end

    test "finds deps in union types" do
      assert Avrogen.Types.external_dependencies(["foo.Bar", "baz.Qux"]) == ["foo.Bar", "baz.Qux"]
      assert Avrogen.Types.external_dependencies(["foo.Bar", "int"]) == ["foo.Bar"]
    end

    test "finds deps in array types" do
      assert Avrogen.Types.external_dependencies(%{"type" => "array", "items" => "foo.Bar"}) == [
               "foo.Bar"
             ]

      assert Avrogen.Types.external_dependencies(%{"type" => "array", "items" => "string"}) == []

      assert Avrogen.Types.external_dependencies(%{"type" => "array", "items" => "bytes"}) == []

      assert Avrogen.Types.external_dependencies(%{
               "type" => "array",
               "items" => ["foo.Bar", "baz.Qux"]
             }) == ["foo.Bar", "baz.Qux"]

      assert Avrogen.Types.external_dependencies(%{
               "type" => "array",
               "items" => ["foo.Bar", "null"]
             }) ==
               ["foo.Bar"]
    end
  end

  describe "is_primitive?" do
    test "detects primitive type in logicalType type" do
      assert Avrogen.Types.is_primitive?(%{"logicalType" => "foo", "type" => "string"})
      assert Avrogen.Types.is_primitive?(%{"logicalType" => "foo", "type" => "bytes"})
    end
  end
end
