defmodule Avrogen.Avro.Types.Union do
  @moduledoc """
    This type is a representation of the [Avro union type](https://avro.apache.org/docs/1.11.0/spec.html#Unions).

    (Note that when a default value is specified for a record field whose type is a union, the type of
    the default value must match the first element of the union. Thus, for unions containing "null",
    the "null" is usually listed first, since the default value of such unions is typically null.)

    Unions may not contain more than one schema with the same type, except for the named types record,
    fixed and enum. For example, unions containing two array types or two map types are not permitted,
    but two types with different names are permitted. (Names permit efficient resolution when reading
    and writing unions.)

    Unions may not immediately contain other unions.
  """

  alias Avrogen.Avro.Schema
  use TypedStruct

  typedstruct do
    # A JSON array of the possible types in this union.
    field :types, [Schema.non_union()]
  end

  def parse(value) when is_list(value), do: %__MODULE__{types: Enum.map(value, &Schema.parse/1)}

  def has_member?(%__MODULE__{types: types}, type), do: Enum.member?(types, type)
end

alias Avrogen.Avro.Schema.CodeGenerator
alias Avrogen.Avro.Types.Union
alias Avrogen.Utils.MacroUtils

defimpl Jason.Encoder, for: Union do
  def encode(%Union{types: types}, opts), do: Jason.Encode.list(types, opts)
end

defimpl CodeGenerator, for: Union do
  def external_dependencies(%{types: types}),
    do: Enum.flat_map(types, &CodeGenerator.external_dependencies/1)

  def normalize(%Union{types: types}, global, parent_namespace, scope_embedded_types) do
    {types, global} =
      Enum.reduce(types, {[], global}, fn type, {types, global} ->
        {updated_schema, global} =
          CodeGenerator.normalize(type, global, parent_namespace, scope_embedded_types)

        {[updated_schema | types], global}
      end)

    {%Union{types: Enum.reverse(types)}, global}
  end

  def elixir_type(%Union{types: types}) do
    types
    |> Enum.map(&CodeGenerator.elixir_type/1)
    |> Enum.map_join(" | ", &Macro.to_string/1)
    |> Code.string_to_quoted!()
  end

  def encode_function(%Union{types: types}, function_name, global) do
    functions =
      types
      |> Enum.map(&CodeGenerator.encode_function(&1, function_name, global))
      |> MacroUtils.flatten_block()

    quote do
      (unquote_splicing(functions))

      # This is not correct behaviour, but is the current behaviour of the library.
      # We should remove this and return and error simply have a match failure in a
      # future release
      defp unquote(function_name)(value), do: value
    end
  end

  def decode_function(%Union{types: types}, function_name, global) do
    functions =
      types
      |> Enum.with_index()
      |> Enum.map(fn {type, i} ->
        CodeGenerator.decode_function(type, :"#{function_name}_#{i}", global)
      end)
      |> Enum.flat_map(&MacroUtils.flatten_block/1)

    clauses =
      types
      |> Enum.with_index()
      |> Enum.map(fn {_type, i} ->
        quote(do: {:error, _} <- unquote(:"#{function_name}_#{i}")(value))
      end)

    # credo:disable-for-lines:3
    quote do
      defp unquote(function_name)(value) do
        with unquote_splicing(clauses) do
          # This is not correct behaviour, but is the current behaviour of the library.
          # We should remove this and return an error here instead but too many tests
          # in pricing depended on this behaviour.
          {:ok, value}
        end
      end

      unquote_splicing(functions)
    end
  end

  def contains_pii?(%Union{types: types}, global),
    do: Enum.any?(types, &CodeGenerator.contains_pii?(&1, global))

  def drop_pii(%Union{types: types}, function_name, global) do
    functions =
      types
      |> Enum.map(&CodeGenerator.drop_pii(&1, function_name, global))
      |> MacroUtils.flatten_block()

    quote(do: (unquote_splicing(functions)))
  end

  def random_instance(%Union{types: types}, range_opts, global) do
    constructors = Enum.map(types, &CodeGenerator.random_instance(&1, range_opts, global))
    quote(do: [unquote_splicing(constructors)])
  end
end
