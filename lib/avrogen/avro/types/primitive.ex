defmodule Avrogen.Avro.Types.Primitive do
  @moduledoc """
    This type is a representation of the [Avro array type](https://avro.apache.org/docs/1.11.0/spec.html#schema_primitive).
  """

  use TypedStruct

  @type primitive_type :: :null | :boolean | :int | :long | :float | :double | :bytes | :string

  typedstruct do
    # The type name of this primitive type which is one of the following:
    # - :null: no value
    # - :boolean: a binary value
    # - :int: 32-bit signed integer
    # - :long: 64-bit signed integer
    # - :float: single precision (32-bit) IEEE 754 floating-point number
    # - :double: double precision (64-bit) IEEE 754 floating-point number
    # - :bytes: sequence of 8-bit unsigned bytes
    # - :string: unicode character sequence
    field :type, primitive_type()
  end

  @primitive [
    "null",
    "boolean",
    "int",
    "long",
    "float",
    "double",
    "bytes",
    "string"
  ]
  defguard is_primitive(value) when value in @primitive

  def parse(value) when is_primitive(value), do: %__MODULE__{type: parse_type(value)}

  def null, do: %__MODULE__{type: :null}

  def parse_type("null"), do: :null
  def parse_type("boolean"), do: :boolean
  def parse_type("int"), do: :int
  def parse_type("long"), do: :long
  def parse_type("float"), do: :float
  def parse_type("double"), do: :double
  def parse_type("bytes"), do: :bytes
  def parse_type("string"), do: :string

  def encode_type(:null), do: "null"
  def encode_type(:boolean), do: "boolean"
  def encode_type(:int), do: "int"
  def encode_type(:long), do: "long"
  def encode_type(:float), do: "float"
  def encode_type(:double), do: "double"
  def encode_type(:bytes), do: "bytes"
  def encode_type(:string), do: "string"

  def _elixir_type(:null), do: quote(do: nil)
  def _elixir_type(:boolean), do: quote(do: boolean())
  def _elixir_type(:int), do: quote(do: integer())
  def _elixir_type(:long), do: quote(do: integer())
  def _elixir_type(:float), do: quote(do: float())
  def _elixir_type(:double), do: quote(do: float())
  def _elixir_type(:bytes), do: quote(do: binary())
  def _elixir_type(:string), do: quote(do: String.t())

  def guard_clause(:null), do: :is_nil
  def guard_clause(:boolean), do: :is_boolean
  def guard_clause(:int), do: :is_integer
  def guard_clause(:long), do: :is_integer
  def guard_clause(:float), do: :is_float
  def guard_clause(:double), do: :is_float
  def guard_clause(:bytes), do: :is_binary
  def guard_clause(:string), do: :is_binary

  def default_value(:null), do: nil
  def default_value(:boolean), do: false
  def default_value(:int), do: 0
  def default_value(:long), do: 0
  def default_value(:float), do: 0.0
  def default_value(:double), do: 0.0
  def default_value(:bytes), do: ""
  def default_value(:string), do: ""
end

alias Avrogen.Avro.Types.Primitive
alias Avrogen.Avro.Schema.CodeGenerator

defimpl Jason.Encoder, for: Primitive do
  def encode(%Primitive{type: type}, opts) do
    type |> Primitive.encode_type() |> Jason.Encode.string(opts)
  end
end

defimpl CodeGenerator, for: Primitive do
  def external_dependencies(_), do: []

  def normalize(value, global, _parent_namespace, _scope_embedded_types), do: {value, global}

  def elixir_type(%Primitive{type: type}), do: Primitive._elixir_type(type)

  def encode_function(%Primitive{type: :null}, function_name, _global) do
    quote do
      defp unquote(function_name)(nil), do: nil
    end
  end

  def encode_function(%Primitive{type: :string}, function_name, _global) do
    # In the previous version of the library we allowed passing atoms when the field type is
    # a "string". We can decide to remove this if we would like
    quote do
      defp unquote(function_name)(value) when is_binary(value) or is_atom(value), do: value
    end
  end

  def encode_function(%Primitive{type: type}, function_name, _global) do
    guard_clause = Primitive.guard_clause(type)

    quote do
      defp unquote(function_name)(value) when unquote(guard_clause)(value), do: value
    end
  end

  def decode_function(%Primitive{type: :null}, function_name, _global) do
    quote do
      defp unquote(function_name)(nil), do: {:ok, nil}
      defp unquote(function_name)(_), do: {:error, "Not a null value"}
    end
  end

  def decode_function(%Primitive{}, function_name, _global) do
    quote do
      defp unquote(function_name)(value), do: {:ok, value}
    end
  end

  def contains_pii?(%Primitive{}, _global), do: false

  def drop_pii(%Primitive{type: type}, function_name, _global) do
    guard_clause = Primitive.guard_clause(type)

    quote do
      def unquote(function_name)(value) when unquote(guard_clause)(value),
        do: unquote(Primitive.default_value(type))
    end
  end

  def random_instance(%Primitive{type: type}, [], _global) do
    case type do
      :null -> quote(do: Constructors.nothing())
      :boolean -> quote(do: Constructors.boolean())
      :int -> quote(do: Constructors.integer())
      :long -> quote(do: Constructors.integer())
      :float -> quote(do: Constructors.float())
      :double -> quote(do: Constructors.float())
      :bytes -> quote(do: Constructors.string())
      :string -> quote(do: Constructors.string())
    end
  end

  def random_instance(%Primitive{type: type}, range_opts, _global) do
    range_opts = range_opts[type]

    case type do
      :null -> quote(do: Constructors.nothing())
      :boolean -> quote(do: Constructors.boolean())
      :int -> quote(do: Constructors.integer(unquote(range_opts)))
      :long -> quote(do: Constructors.integer(unquote(range_opts)))
      :float -> quote(do: Constructors.float(unquote(range_opts)))
      :double -> quote(do: Constructors.float(unquote(range_opts)))
      :bytes -> quote(do: Constructors.string(unquote(range_opts)))
      :string -> quote(do: Constructors.string(unquote(range_opts)))
    end
  end
end
