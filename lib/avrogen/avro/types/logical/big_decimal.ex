defmodule Avrogen.Avro.Types.Logical.BigDecimal do
  @moduledoc """
    This represents the logical type of the scalable precision [decimal](https://avro.apache.org/docs/1.12.0/specification/#decimal)
    introduced in version 1.12.0

    Like the fixed precision decimal logical type, it represents an arbitrary-precision signed decimal number of
    the form unscaled × 10-scale. However, the scale and precision do not need to be known in advance.

    To quote the docs:

    > Here, as scale property is stored in value itself it needs more bytes than preceding decimal type, but it allows more flexibility.
  """

  @logical_type "big-decimal"
  @avro_type "bytes"

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    # This will always be set to @logical_type it is maintained to simplify
    # the JSON encoding logic.
    field :logicalType, String.t()
    # This will always be set to @avro_type it is maintained to simplify the JSON encoding logic.
    field :type, String.t()
  end

  def parse(%{"logicalType" => @logical_type, "type" => @avro_type}) do
    %__MODULE__{
      type: @avro_type,
      logicalType: @logical_type
    }
  end
end

alias Avrogen.Avro.Types.Logical.BigDecimal
alias Avrogen.Avro.Schema.CodeGenerator

defimpl CodeGenerator, for: BigDecimal do
  def external_dependencies(_), do: []

  def normalize(value, global, _parent_namespace, _scope_embedded_types), do: {value, global}

  def elixir_type(%BigDecimal{}), do: quote(do: Decimal.t())

  def encode_function(%BigDecimal{}, function_name, _global) do
    quote do
      defp unquote(function_name)(%Decimal{} = decimal), do: Decimal.to_string(decimal)
    end
  end

  def decode_function(%BigDecimal{}, function_name, _global) do
    quote do
      defp unquote(function_name)(decimal) when is_binary(decimal) do
        case Decimal.parse(decimal) do
          {decimal, _} -> {:ok, decimal}
          :error -> {:error, "Not a decimal"}
        end
      end
    end
  end

  def contains_pii?(%BigDecimal{}, _global), do: false

  def drop_pii(%BigDecimal{}, function_name, _global) do
    quote do
      def unquote(function_name)(%Decimal{}), do: Decimal.new("0")
    end
  end

  def random_instance(
        %BigDecimal{logicalType: logicalType},
        range_opts,
        _global
      ) do
    range_opts
    |> Keyword.get(String.to_atom(logicalType), [])
    |> case do
      [] -> quote(do: Constructors.decimal())
      opts -> quote(do: Constructors.decimal(unquote(opts)))
    end
  end
end
