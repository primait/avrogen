defmodule Avrogen.Avro.Types.Logical.TimestampMicros do
  @moduledoc """
    This type represents the [timestamp-micros](https://avro.apache.org/docs/1.11.1/specification/#timestamp-microsecond-precision)
    type according to the specification

    The timestamp-micros logical type represents a date with a time and a reference to a particular
    time zone, with a precision of one microsecond.

    A timestamp-micros logical type annotates an Avro long, where the long stores the number of
    microseconds after midnight, 00:00:00.000.
  """

  use TypedStruct

  @logical_type "timestamp-micros"
  @avro_type "long"

  @derive Jason.Encoder
  typedstruct do
    # This will always be set to @logical_type it is maintained to simplify
    # the JSON encoding logic.
    field :logicalType, String.t()
    # This will always be set to @avro_type it is maintained to simplify the JSON encoding logic.
    field :type, String.t()
  end

  def parse(%{"logicalType" => @logical_type, "type" => @avro_type}),
    do: %__MODULE__{logicalType: @logical_type, type: @avro_type}
end

alias Avrogen.Avro.Types.Logical.TimestampMicros
alias Avrogen.Avro.Schema.CodeGenerator

defimpl CodeGenerator, for: TimestampMicros do
  def external_dependencies(_), do: []

  def normalize(value, global, _parent_namespace, _scope_embedded_types), do: {value, global}

  def elixir_type(%TimestampMicros{}), do: quote(do: DateTime.t())

  def encode_function(%TimestampMicros{}, function_name, _global) do
    quote do
      defp unquote(function_name)(%DateTime{} = timestamp),
        do: DateTime.to_unix(timestamp, :microsecond)
    end
  end

  def decode_function(%TimestampMicros{}, function_name, _global) do
    quote do
      defp unquote(function_name)(timestamp) when is_number(timestamp),
        do: DateTime.from_unix(timestamp, :microsecond)

      defp unquote(function_name)(timestamp),
        do: {:error, "Expected a long, got: #{inspect(timestamp)}"}
    end
  end

  def contains_pii?(%TimestampMicros{}, _global), do: false

  def drop_pii(%TimestampMicros{}, function_name, _global) do
    quote do
      def unquote(function_name)(%DateTime{}), do: DateTime.utc_now()
    end
  end

  def random_instance(%TimestampMicros{logicalType: logicalType}, range_opts, _global) do
    range_opts
    |> Keyword.get(String.to_atom(logicalType), [])
    |> case do
      [] -> quote(do: Constructors.datetime())
      opts -> quote(do: Constructors.datetime(unquote(opts)))
    end
  end
end
