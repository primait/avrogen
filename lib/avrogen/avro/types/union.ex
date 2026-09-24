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
  alias Avrogen.Avro.Types.Record
  alias Avrogen.Avro.Types.Reference

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
    {clauses, helpers} =
      Enum.reduce(types, {[], []}, fn type, {clauses, helpers} ->
        {member_clauses, member_helpers} =
          encode_union_member(type, function_name, global)

        {clauses ++ member_clauses, helpers ++ member_helpers}
      end)

    quote do
      unquote_splicing(clauses)
      unquote_splicing(helpers)
    end
  end

  defp encode_union_member(%Reference{} = reference, function_name, global) do
    encode_union_member(global[reference.name] || reference, function_name, global)
  end

  defp encode_union_member(%Record{} = record, function_name, global) do
    record_module = Code.string_to_quoted!(record.name)
    fullname = Record.fullname(record, nil)
    record_encoder_name = :"#{function_name}_record"

    clause =
      quote do
        defp unquote(function_name)(%unquote(record_module){} = value) do
          {unquote(fullname), unquote(record_encoder_name)(value)}
        end
      end

    helper =
      CodeGenerator.encode_function(record, record_encoder_name, global)
      |> MacroUtils.flatten_block()

    {[clause], helper}
  end

  defp encode_union_member(type, function_name, global) do
    {
      CodeGenerator.encode_function(type, function_name, global)
      |> MacroUtils.flatten_block(),
      []
    }
  end

  def decode_function(%Union{types: types}, function_name, global) do
    functions =
      types
      |> Enum.with_index()
      |> Enum.map(fn {type, i} ->
        CodeGenerator.decode_function(type, :"#{function_name}_#{i}", global)
      end)
      |> Enum.flat_map(&MacroUtils.flatten_block/1)

    tagged_clauses =
      types
      |> Enum.with_index()
      |> Enum.flat_map(fn {type, index} ->
        tagged_decode_clause(type, function_name, :"#{function_name}_#{index}", global)
      end)

    clauses =
      types
      |> Enum.with_index()
      |> Enum.map(fn {_type, i} ->
        quote do
          {:error, _} <-
            try do
              unquote(:"#{function_name}_#{i}")(value)
            rescue
              error ->
                {:error, Exception.message(error)}
            end
        end
      end)

    # credo:disable-for-lines:3
    quote do
      unquote_splicing(tagged_clauses)

      defp unquote(function_name)(value) do
        with unquote_splicing(clauses) do
          {:error, "Failed to decode union value #{inspect(value)}"}
        end
      end

      unquote_splicing(functions)
    end
  end

  defp tagged_decode_clause(%Reference{} = reference, function_name, branch_function_name, global) do
    tagged_decode_clause(
      global[reference.name] || reference,
      function_name,
      branch_function_name,
      global
    )
  end

  defp tagged_decode_clause(%Record{} = record, function_name, branch_function_name, _global) do
    fullname = Record.fullname(record, nil)

    [
      quote do
        defp unquote(function_name)({unquote(fullname), value}),
          do: unquote(branch_function_name)(value)
      end
    ]
  end

  defp tagged_decode_clause(_, _function_name, _branch_function_name, _global), do: []

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
