defmodule Avrogen.Avro.Types.Logical.TimestampMillis do
  @moduledoc """
    This type represents the [timestamp-millis](https://avro.apache.org/docs/1.11.0/spec.html#Timestamp+%28millisecond+precision%29)
    type according to the specification

    The time-millis logical type represents a time of day, with no reference to a particular
    calendar, time zone or date, with a precision of one millisecond.

    A time-millis logical type annotates an Avro int, where the int stores the number of
    milliseconds after midnight, 00:00:00.000.
  """

  use TypedStruct

  @logical_type "timestamp-millis"
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

alias Avrogen.Avro.Types.Logical.TimestampMillis
alias Avrogen.Avro.Schema.CodeGenerator

defimpl CodeGenerator, for: TimestampMillis do
  def external_dependencies(_), do: []

  def normalize(value, global, _parent_namespace, _scope_embedded_types), do: {value, global}

  def elixir_type(%TimestampMillis{}), do: quote(do: DateTime.t())

  def encode_function(%TimestampMillis{}, function_name, _global) do
    quote do
      defp unquote(function_name)(%DateTime{} = timestamp),
        do: DateTime.to_unix(timestamp, :millisecond)
    end
  end

  def decode_function(%TimestampMillis{}, function_name, _global) do
    quote do
      defp unquote(function_name)(timestamp), do: DateTime.from_unix(timestamp, :millisecond)
    end
  end

  def contains_pii?(%TimestampMillis{}, _global), do: false

  def drop_pii(%TimestampMillis{}, function_name, _global) do
    quote do
      def unquote(function_name)(%DateTime{}), do: DateTime.utc_now()
    end
  end

  def random_instance(%TimestampMillis{logicalType: logicalType}, range_opts, _global) do
    range_opts
    |> Keyword.get(String.to_atom(logicalType), [])
    |> case do
      [] -> quote(do: Constructors.datetime())
      opts -> quote(do: Constructors.datetime(unquote(opts)))
    end
  end
end
