alias Avrogen.Avro.Schema.CodeGenerator
alias Avrogen.Avro.Types

defmodule Avrogen.Avro.Types.Record.Field do
  @moduledoc """
    This type is a representation of the [Avro record field type](https://avro.apache.org/docs/1.11.0/spec.html#Record).
  """
  alias Avrogen.Avro.Schema
  use TypedStruct

  @type order :: :ascending | :descending | :ignore

  typedstruct do
    # A JSON string providing the name of the enum (required).
    field :name, String.t(), enforce: true
    # A JSON string providing documentation to the user of this schema (optional).
    field :doc, String.t() | nil
    # The type of this field as an avro schema
    field :type, Schema.t(), enforce: true
    # A default value for this field, only used when reading instances that lack the field
    # for schema evolution purposes. The presence of a default value does not make the field
    # optional at encoding time. Permitted values depend on the field's schema type, according
    # to the table below. Default values for union fields correspond to the first schema in
    # the union. Default values for bytes and fixed fields are JSON strings, where Unicode
    # code points 0-255 are mapped to unsigned 8-bit byte values 0-255. Avro encodes a field
    # even if its value is equal to its default.
    field :default, any()
    # Specifies how this field impacts sort ordering of this record (optional). Valid values
    # are "ascending" (the default), "descending", or "ignore". For more details on how this
    # is used, see the sort order section below.
    field :order, order()
    # A JSON array of strings, providing alternate names for this enum (optional).
    field :aliases, [String.t()]
    # **This is not an official field according to the specification**
    # Identifies a field as containing [pii](https://www.gdpreu.org/the-regulation/key-concepts/personal-data/#:~:text=This%20is%20why%20it%20is,the%20anonymization%20must%20be%20irreversible.)
    field :pii, boolean(), default: false
    # **This is not an official field according to the specification**
    # Used to specify the range of the values created by the random_instance method.
    field :range, map()
  end

  def parse(%{"name" => name, "type" => type} = field) do
    %__MODULE__{
      name: name,
      doc: field["doc"],
      type: Schema.parse(type),
      default: parse_default_value(field["default"]),
      order: field["order"],
      aliases: field["aliases"],
      pii: field["pii"] || false,
      range: field["range"]
    }
  end

  def name(%__MODULE__{name: name}), do: name

  def comment(%__MODULE__{doc: nil, name: name}), do: "#{name}: #{name}"
  def comment(%__MODULE__{doc: doc, name: name}), do: "#{name}: #{doc}"

  def has_default?(%__MODULE__{default: nil}), do: false
  def has_default?(%__MODULE__{}), do: true

  def is_pii?(%__MODULE__{pii: pii}), do: pii

  def range_opts(%__MODULE__{range: nil}), do: []
  def range_opts(%__MODULE__{range: range}), do: to_keywords(range)

  def to_keywords(data) when is_map(data) or is_list(data) do
    data
    |> Enum.to_list()
    |> Enum.map(fn {k, v} -> {String.to_atom(k), to_keywords(v)} end)
  end

  def to_keywords(val), do: val

  def bind_with_default(%__MODULE__{name: name, default: default}) do
    variable_name = Code.string_to_quoted!(name)

    case default do
      default when is_nil(default) or default == "null" ->
        quote(do: unquote(variable_name) = avro_map[unquote(name)])

      default ->
        quote(do: unquote(variable_name) = avro_map[unquote(name)] || unquote(default))
    end
  end

  def typed_struct_field(%__MODULE__{name: name, type: type, default: nil} = field) do
    name = String.to_atom(name)

    quote do
      field unquote(name), unquote(CodeGenerator.elixir_type(type)),
        enforce: unquote(enforce?(field))
    end
  end

  def typed_struct_field(%__MODULE__{name: name, type: type, default: default} = field) do
    name = String.to_atom(name)

    quote do
      field unquote(name), unquote(CodeGenerator.elixir_type(type)),
        enforce: unquote(enforce?(field)),
        default: unquote(default)
    end
  end

  def parse_default_value(nil), do: nil
  def parse_default_value("null"), do: nil
  def parse_default_value(value), do: value

  def enforce?(%__MODULE__{type: %Types.Union{} = union}),
    do: not Types.Union.has_member?(union, Types.Primitive.null())

  def enforce?(%__MODULE__{}), do: true

  def from_avro_map_clause(%__MODULE__{name: name} = field) do
    name = Code.string_to_quoted!(name)
    function_name = decode_function_name(field)

    quote do
      unquote(function_name)(unquote(name))
    end
  end

  def to_avro_map_clause(%__MODULE__{name: name} = field) do
    name = String.to_atom(name)
    function_name = encode_function_name(field)

    quote do
      unquote(function_name)(value.unquote(name))
    end
  end

  def encode_function_name(%__MODULE__{name: name}), do: :"encode_#{String.to_atom(name)}"
  def decode_function_name(%__MODULE__{name: name}), do: :"decode_#{String.to_atom(name)}"
  def drop_pii_function_name(%__MODULE__{name: name}), do: :"drop_pii_#{String.to_atom(name)}"
end

alias Avrogen.Avro.Types.Record.Field
alias Avrogen.Utils.MacroUtils

defimpl CodeGenerator, for: Field do
  def external_dependencies(%Field{type: type}), do: CodeGenerator.external_dependencies(type)

  def normalize(%Field{type: type} = field, global, parent_namespace, scope_embedded_types) do
    {updated_schema, global} =
      CodeGenerator.normalize(type, global, parent_namespace, scope_embedded_types)

    {%Field{field | type: updated_schema}, global}
  end

  def elixir_type(%Field{type: type}), do: CodeGenerator.elixir_type(type)

  def encode_function(%Field{type: type} = field, _function_name, global) do
    type
    |> CodeGenerator.encode_function(Field.encode_function_name(field), global)
    |> MacroUtils.flatten_block()
  end

  def decode_function(%Field{type: type} = field, _function_name, global) do
    function_name = Field.decode_function_name(field)
    inner_function_name = :"try_#{function_name}"

    inner =
      type
      |> CodeGenerator.decode_function(inner_function_name, global)
      |> MacroUtils.flatten_block()

    quote do
      defp unquote(function_name)(value) do
        value
        |> unquote(inner_function_name)()
        |> unwrap!()
      end

      unquote_splicing(inner)
    end
  end

  def contains_pii?(%Field{pii: true}, _global), do: true
  def contains_pii?(%Field{type: type}, global), do: CodeGenerator.contains_pii?(type, global)

  def drop_pii(%Field{type: type} = field, _function_name, global) do
    type
    |> CodeGenerator.drop_pii(Field.drop_pii_function_name(field), global)
    |> MacroUtils.flatten_block()
  end

  def random_instance(%Field{type: type} = field, _range_opts, global),
    do: CodeGenerator.random_instance(type, Field.range_opts(field), global)
end
