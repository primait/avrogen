defmodule Avrogen.Avro.Types.Map do
  @moduledoc """
    This type is a representation of the [Avro map type](https://avro.apache.org/docs/1.11.0/spec.html#Maps).
  """

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

alias Avrogen.Avro.Schema.CodeGenerator
alias Avrogen.Avro.Types
alias Avrogen.Avro.Types.Map

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
  def drop_pii(%Map{value_schema: value_schema}, function_name, global) do
    values_fn = :"#{function_name}_values"

    quote do
      unquote(map_reduce_clause(function_name, values_fn))
      unquote_splicing(values_fn_clauses(pii_types_in(value_schema, global), values_fn, global))
    end
  end

  # Generates all clauses for `values_fn` in the correct order:
  #   specific match clauses (one per PII type)
  #   catch-all
  #   nested helpers (for values_fn_values and deeper)
  defp values_fn_clauses(pii_types, values_fn, global) do
    direct = Enum.map(pii_types, &direct_value_clause(&1, values_fn, global))
    nested = Enum.flat_map(pii_types, &nested_value_helpers(&1, values_fn, global))

    catch_all =
      quote do
        def unquote(values_fn)(value), do: value
      end

    direct ++ [catch_all] ++ nested
  end

  defp direct_value_clause(%Types.Map{}, values_fn, _global),
    do: map_reduce_clause(values_fn, :"#{values_fn}_values")

  defp direct_value_clause(schema, values_fn, global),
    do: CodeGenerator.drop_pii(schema, values_fn, global)

  defp nested_value_helpers(%Types.Map{value_schema: inner_schema}, values_fn, global),
    do: values_fn_clauses(pii_types_in(inner_schema, global), :"#{values_fn}_values", global)

  defp nested_value_helpers(_, _, _), do: []

  defp map_reduce_clause(fn_name, values_fn) do
    quote do
      def unquote(fn_name)(value) when is_map(value) do
        Enum.reduce(value, %{}, fn {k, v}, acc ->
          Elixir.Map.put(acc, k, unquote(values_fn)(v))
        end)
      end
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
