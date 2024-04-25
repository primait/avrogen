defmodule Avrogen.Avro.Types.Logical.DecimalString do
  @moduledoc """
    This type actually does not conform to the specification for a decimal.

    However, this is in use in our code base. This type is when a string represents a
    decimal value.
  """

  use TypedStruct

  @logical_types ["decimal", "big_decimal"]
  @avro_type "string"

  @derive Jason.Encoder
  typedstruct do
    # This will always be set to one of the @logical_types it is maintained to simplify
    # the JSON encoding logic.
    field :logicalType, String.t()
    # This will always be set to @avro_type it is maintained to simplify the JSON encoding logic.
    field :type, String.t()
  end

  def parse(%{"logicalType" => logical_type, "type" => @avro_type})
      when logical_type in @logical_types,
      do: %__MODULE__{logicalType: logical_type, type: @avro_type}
end

alias Avrogen.Avro.Types.Logical.DecimalString
alias Avrogen.Avro.Schema.CodeGenerator

defimpl CodeGenerator, for: DecimalString do
  def external_dependencies(_), do: []

  def normalize(value, global, _parent_namespace, _scope_embedded_types), do: {value, global}

  def elixir_type(%DecimalString{}), do: quote(do: Decimal.t())

  def encode_function(%DecimalString{}, function_name, _global) do
    quote do
      defp unquote(function_name)(%Decimal{} = decimal), do: Decimal.to_string(decimal)
    end
  end

  def decode_function(%DecimalString{}, function_name, _global) do
    quote do
      defp unquote(function_name)(decimal) when is_binary(decimal) do
        case Decimal.parse(decimal) do
          {decimal, _} -> {:ok, decimal}
          :error -> {:error, "Not a decimal"}
        end
      end
    end
  end

  def contains_pii?(%DecimalString{}, _global), do: false

  def drop_pii(%DecimalString{}, function_name, _global) do
    quote do
      def unquote(function_name)(%Decimal{}), do: Decimal.new("0")
    end
  end

  def random_instance(%DecimalString{logicalType: logicalType}, range_opts, _global) do
    range_opts
    |> Keyword.get(String.to_atom(logicalType), [])
    |> case do
      [] -> quote(do: Constructors.decimal())
      opts -> quote(do: Constructors.decimal(unquote(opts)))
    end
  end
end
