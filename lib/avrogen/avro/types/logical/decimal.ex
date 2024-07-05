defmodule Avrogen.Avro.Types.Logical.Decimal do
  @moduledoc """
    This represents the logical type of the [decimal](https://avro.apache.org/docs/1.11.1/specification/_print/#decimal)
    in the specification

    The decimal logical type represents an arbitrary-precision signed decimal number of
    the form unscaled × 10-scale.

    Officially this typs can be either bytes or fixed, currently I have not added support for fixed.

    The following attributes are supported:

    - scale, a JSON integer representing the scale (optional).
      If not specified the scale is 0.
    - precision, a JSON integer representing the (maximum) precision of decimals
      stored in this type (required).

    Precision must be a positive integer greater than zero. If the underlying type is a
    fixed, then the precision is limited by its size. An array of length n can store at
    most floor(log_10(28 × n - 1 - 1)) base-10 digits of precision.

    Scale must be zero or a positive integer less than or equal to the precision.

    For the purposes of schema resolution, two schemas that are decimal logical types
    match if their scales and precisions match.
  """

  @logical_type "decimal"
  @avro_type "bytes"

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    # This will always be set to @logical_type it is maintained to simplify
    # the JSON encoding logic.
    field :logicalType, String.t()
    # This will always be set to @avro_type it is maintained to simplify the JSON encoding logic.
    field :type, String.t()

    # a JSON integer representing the (maximum) precision of decimals stored in this type (required).
    field :precision, integer(), enforce: true
    # a JSON integer representing the scale (optional). If not specified the scale is 0.
    field :scale, integer(), default: 0
  end

  def parse(
        %{"logicalType" => @logical_type, "type" => @avro_type, "precision" => precision} =
          decimal
      ) do
    %__MODULE__{
      type: @avro_type,
      logicalType: @logical_type,
      precision: precision,
      scale: decimal["scale"] || 0
    }
  end

  def number_of_bytes(%__MODULE__{precision: precision}) do
    10
    |> :math.pow(precision)
    |> :math.log2()
    |> Kernel./(8)
    |> ceil()
    |> Kernel.*(8)
  end
end

alias Avrogen.Avro.Types.Logical
alias Avrogen.Avro.Schema.CodeGenerator

defimpl CodeGenerator, for: Logical.Decimal do
  def external_dependencies(_), do: []

  def normalize(value, global, _parent_namespace, _scope_embedded_types), do: {value, global}

  def elixir_type(%Logical.Decimal{}), do: quote(do: Decimal.t())

  def encode_function(%Logical.Decimal{scale: scale} = decimal, function_name, _global) do
    scale = :math.pow(10, scale) |> trunc()
    number_of_bytes = Logical.Decimal.number_of_bytes(decimal)

    quote do
      defp unquote(function_name)(%Decimal{} = decimal) do
        value = decimal |> Decimal.mult(unquote(scale)) |> Decimal.to_integer()

        <<value::unquote(number_of_bytes)-signed-integer-big>>
      end
    end
  end

  def decode_function(%Logical.Decimal{scale: scale} = decimal, function_name, _global) do
    divisor = :math.pow(10, scale) |> trunc()
    number_of_bytes = Logical.Decimal.number_of_bytes(decimal)

    quote do
      defp unquote(function_name)(<<value::unquote(number_of_bytes)-signed-integer-big>>) do
        {:ok,
         value |> Decimal.new() |> Decimal.div(unquote(divisor)) |> Decimal.round(unquote(scale))}
      end

      defp unquote(function_name)(_), do: {:error, "Unexpected value"}
    end
  end

  def contains_pii?(%Logical.Decimal{}, _global), do: false

  def drop_pii(%Logical.Decimal{scale: scale}, function_name, _global) do
    quote do
      def unquote(function_name)(%Logical.Decimal{}),
        do: Decimal.new("0") |> Decimal.round(unquote(scale))
    end
  end

  def random_instance(
        %Logical.Decimal{logicalType: logicalType, scale: scale},
        range_opts,
        _global
      ) do
    range_opts
    |> Keyword.get(String.to_atom(logicalType), [])
    |> Keyword.merge(scale: scale)
    |> case do
      [] -> quote(do: Constructors.decimal())
      opts -> quote(do: Constructors.decimal(unquote(opts)))
    end
  end
end
