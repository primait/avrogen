defmodule Avrogen.Avro.Types.Array do
  @moduledoc """
    This type is a representation of the [Avro array type](https://avro.apache.org/docs/1.11.0/spec.html#Arrays).
  """

  alias Avrogen.Avro.Schema

  use TypedStruct
  @identifier "array"

  typedstruct do
    # The schema of the array's items.
    field :items_schema, Schema.t(), enforce: true
    # The default value of this array
    field :default, any()
  end

  def identifier, do: @identifier

  def parse(%{"type" => @identifier, "items" => items}),
    do: %__MODULE__{items_schema: Schema.parse(items)}
end

alias Avrogen.Avro.Types.Array
alias Avrogen.Avro.Schema.CodeGenerator

defimpl Jason.Encoder, for: Array do
  def encode(%Array{items_schema: items, default: default}, opts) do
    %{
      type: Array.identifier(),
      default: default,
      items: items
    }
    |> Map.reject(fn {_k, v} -> is_nil(v) end)
    |> Jason.Encode.map(opts)
  end
end

defimpl CodeGenerator, for: Array do
  def external_dependencies(%Array{items_schema: items_schema}),
    do: CodeGenerator.external_dependencies(items_schema)

  def normalize(
        %Array{items_schema: items_schema} = array,
        global,
        parent_namespace,
        scope_embedded_types
      ) do
    {updated_schema, global} =
      CodeGenerator.normalize(items_schema, global, parent_namespace, scope_embedded_types)

    {%Array{array | items_schema: updated_schema}, global}
  end

  def elixir_type(%Array{items_schema: items_schema}),
    do: quote(do: [unquote(CodeGenerator.elixir_type(items_schema))])

  def encode_function(%Array{items_schema: items_schema}, function_name, global) do
    inner = CodeGenerator.encode_function(items_schema, function_name, global)

    quote do
      defp unquote(function_name)(value) when is_list(value),
        do: Enum.map(value, fn item -> unquote(function_name)(item) end)

      unquote(inner)
    end
  end

  def decode_function(%Array{items_schema: items_schema}, function_name, global) do
    inner = CodeGenerator.decode_function(items_schema, function_name, global)

    quote do
      defp unquote(function_name)(value) when is_list(value),
        do:
          value
          |> Enum.reduce_while({:ok, []}, fn value, {:ok, acc} ->
            case unquote(function_name)(value) do
              {:ok, value} -> {:cont, {:ok, [value | acc]}}
              {:error, _} = error -> {:halt, error}
            end
          end)
          |> then(fn
            {:ok, vals} -> {:ok, Enum.reverse(vals)}
            {:error, error} -> {:error, error}
          end)

      unquote(inner)
    end
  end

  def contains_pii?(%Array{}, _global), do: false

  def drop_pii(%Array{}, function_name, _global) do
    quote do
      def unquote(function_name)(value) when is_list(value), do: []
    end
  end

  def random_instance(%Array{items_schema: items_schema}, range_opts, global) do
    inner = CodeGenerator.random_instance(items_schema, range_opts, global)
    quote(do: Constructors.list(unquote(inner)))
  end
end
