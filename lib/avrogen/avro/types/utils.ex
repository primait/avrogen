defmodule Avrogen.Avro.Types.Utils do
  @moduledoc """
    Shared utils for working with Avro schema types
  """

  @type namespaced_type :: %{
          required(:namespace) => String.t() | nil,
          required(:name) => String.t(),
          optional(atom()) => any()
        }
  @type parent_namespace :: String.t() | nil
  @type scoped_embedded_types :: boolean()

  @spec fullname(namespaced_type(), parent_namespace()) :: String.t()
  def fullname(%{namespace: nil, name: name}, nil), do: name
  def fullname(%{namespace: nil, name: name}, namespace), do: "#{namespace}.#{name}"
  def fullname(%{namespace: namespace, name: name}, _), do: "#{namespace}.#{name}"

  @spec namespace(namespaced_type(), parent_namespace(), scoped_embedded_types()) :: String.t()
  def namespace(%{namespace: nil}, namespace, false), do: namespace
  def namespace(%{namespace: namespace}, _, false), do: namespace
  def namespace(%{namespace: nil, name: name}, namespace, true), do: combine(namespace, name)
  def namespace(%{namespace: namespace, name: name}, nil, true), do: combine(namespace, name)

  def namespace(%{namespace: namespace, name: name}, parent, true),
    do: combine(parent, namespace, name)

  defp combine(name), do: Macro.underscore(name)
  defp combine(namespace, name), do: "#{namespace}.#{combine(name)}"
  defp combine(parent, namespace, name), do: "#{parent}.#{combine(namespace, name)}"
end
