defmodule Avrogen.Avro.Types.Map do
  @moduledoc """
    This type is a representation of the [Avro map type](https://avro.apache.org/docs/1.11.0/spec.html#Maps).
  """

  alias Avrogen.Avro.Schema
  alias Avrogen.Avro.Schema
  use TypedStruct
  @identifier "map"

  typedstruct do
    # The schema of the map's values
    field :value_schema, Schema.t(), enforce: true
    # The default value of this map
    field :default, any()
  end

  def identifier, do: @identifier

  def parse(%{"type" => @identifier, "values" => values}),
    do: %__MODULE__{value_schema: Schema.parse(values)}
end

alias Avrogen.Avro.Types
alias Avrogen.Avro.Types.Map
alias Avrogen.Avro.Schema.CodeGenerator

defimpl Jason.Encoder, for: Map do
  def encode(%Map{value_schema: value_schema, default: default}, opts) do
    %{
      type: Map.identifier(),
      default: default,
      values: value_schema
    }
    |> Elixir.Map.reject(fn {_k, v} -> is_nil(v) end)
    |> Jason.Encode.map(opts)
  end
end

alias Avrogen.Utils.MacroUtils

defimpl CodeGenerator, for: Map do
  def external_dependencies(%Map{value_schema: value_schema}),
    do: CodeGenerator.external_dependencies(value_schema)

  def normalize(
        %Map{value_schema: value_schema} = map,
        global,
        parent_namespace,
        scope_embedded_types
      ) do
    {updated_schema, global} =
      CodeGenerator.normalize(value_schema, global, parent_namespace, scope_embedded_types)

    {%Map{map | value_schema: updated_schema}, global}
  end

  def elixir_type(%Map{value_schema: value_schema}),
    do: quote(do: %{String.t() => unquote(CodeGenerator.elixir_type(value_schema))})

  def encode_function(%Map{value_schema: value_schema}, function_name, global) do
    value_function_name = :"#{function_name}_values"

    inner =
      value_schema
      |> CodeGenerator.encode_function(value_function_name, global)
      |> MacroUtils.flatten_block()

    quote do
      defp unquote(function_name)(map) when is_map(map) do
        Enum.reduce(map, %{}, fn {key, value}, acc ->
          Elixir.Map.put(acc, key, unquote(value_function_name)(value))
        end)
      end

      unquote(inner)
    end
  end

  def decode_function(%Map{value_schema: value_schema}, function_name, global) do
    value_function_name = :"#{function_name}_values"

    inner =
      value_schema
      |> CodeGenerator.decode_function(value_function_name, global)
      |> MacroUtils.flatten_block()

    quote do
      defp unquote(function_name)(value) when is_map(value),
        do:
          Enum.reduce_while(value, {:ok, %{}}, fn {key, value}, {:ok, acc} ->
            case unquote(value_function_name)(value) do
              {:ok, value} -> {:cont, {:ok, Elixir.Map.put(acc, key, value)}}
              {:error, _} = error -> {:halt, error}
            end
          end)

      unquote(inner)
    end
  end

  def contains_pii?(%Map{value_schema: value_schema}, global),
    do: CodeGenerator.contains_pii?(value_schema, global)

  # Example:
  # def drop_pii_<function_name>(value) when is_map(value) do
  #   Enum.reduce(value, %{}, fn {k, v}, acc ->
  #     Elixir.Map.put(acc, k, drop_pii_<function_name>_values(v))
  #   end)
  # end
  #
  # def drop_pii_<function_name>_values(%<RecordType>{} = value) do
  #   <RecordType>.drop_pii(value)
  # end
  #
  # def drop_pii_<function_name>_values(value) do
  #   value
  # end

  def drop_pii(%Map{value_schema: value_schema}, function_name, global) do
    values_fn = :"#{function_name}_values"

    value_clauses =
      pii_types_in(value_schema, global)
      |> Enum.map(&CodeGenerator.drop_pii(&1, values_fn, global))
      |> MacroUtils.flatten_block()

    quote do
      def unquote(function_name)(value) when is_map(value) do
        Enum.reduce(value, %{}, fn {k, v}, acc ->
          Elixir.Map.put(acc, k, unquote(values_fn)(v))
        end)
      end

      unquote_splicing(value_clauses)

      def unquote(values_fn)(value), do: value
    end
  end

  defp pii_types_in(%Types.Union{types: types}, global),
    do: Enum.filter(types, &CodeGenerator.contains_pii?(&1, global))

  defp pii_types_in(schema, global),
    do: if(CodeGenerator.contains_pii?(schema, global), do: [schema], else: [])

  def random_instance(%Map{value_schema: value_schema}, range_opts, global) do
    inner = CodeGenerator.random_instance(value_schema, range_opts, global)
    quote(do: Constructors.map(unquote(inner)))
  end
end
