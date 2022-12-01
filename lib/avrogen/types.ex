defmodule Avrogen.Types do
  @moduledoc """
  Utils for extracting various info from avro schemas types.
  """

  @primitives ["null", "boolean", "int", "long", "float", "double", "bytes", "string"]

  @doc """
  Get a list of external types referenced in a given type.
  """
  def external_dependencies(type) do
    dependencies(type)
    |> Enum.reject(&is_primitive?/1)
  end

  @doc """
  Get a list of types referenced in a given type, inluding any primitives.
  """
  def dependencies(%{"type" => "array", "items" => type}) do
    dependencies(type)
  end

  def dependencies(type) when is_map(type) do
    # TODO: Extract properly from these complex types...
    []
  end

  def dependencies(types) when is_list(types) do
    Enum.flat_map(types, &dependencies/1)
    |> Enum.uniq()
  end

  def dependencies(type) when is_binary(type) do
    [type]
  end

  @doc """
  Returns true if the given type is a primitive.
  """
  def is_primitive?(%{"logicalType" => _, "type" => type}) do
    is_primitive?(type)
  end

  def is_primitive?(%{"type" => "array"}), do: false

  def is_primitive?(type), do: type in @primitives

  defguard is_primitive(type) when type in @primitives
end
