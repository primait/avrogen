defmodule Avrogen.Avro.Types.Logical.LocalTimestampMillis do
  @moduledoc """
    This type represents the [local-timestamp-millis](https://avro.apache.org/docs/1.11.1/specification/_print/#local-timestamp-millisecond-precision)
    type according to the specification

    The local-timestamp-millis logical type represents a time of day, with no reference to a particular
    calendar, time zone or date, with a precision of one millisecond.

    A local-timestamp-millis logical type annotates an Avro long, where the long stores the number of
    milliseconds after midnight, 00:00:00.000.
  """

  use TypedStruct

  @logical_type "local-timestamp-millis"
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

alias Avrogen.Avro.Types.Logical.LocalTimestampMillis
alias Avrogen.Avro.Schema.CodeGenerator

defimpl CodeGenerator, for: LocalTimestampMillis do
  def external_dependencies(_), do: []

  def normalize(value, global, _parent_namespace, _scope_embedded_types), do: {value, global}

  def elixir_type(%LocalTimestampMillis{}), do: quote(do: NaiveDateTime.t())

  def encode_function(%LocalTimestampMillis{}, function_name, _global) do
    quote do
      defp unquote(function_name)(%NaiveDateTime{} = timestamp),
        do: Timex.diff(timestamp, ~N[1970-01-01 00:00:00.000000], :millisecond)
    end
  end

  def decode_function(%LocalTimestampMillis{}, function_name, _global) do
    quote do
      defp unquote(function_name)(timestamp) when is_number(timestamp),
        do:
          {:ok,
           Timex.add(~N[1970-01-01 00:00:00.000000], Timex.Duration.from_milliseconds(timestamp))}

      defp unquote(function_name)(timestamp),
        do: {:error, "Expected a long value, got: #{inspect(timestamp)}"}
    end
  end

  def contains_pii?(%LocalTimestampMillis{}, _global), do: false

  def drop_pii(%LocalTimestampMillis{}, function_name, _global) do
    quote do
      def unquote(function_name)(%NaiveDateTime{}), do: NaiveDateTime.utc_now()
    end
  end

  def random_instance(%LocalTimestampMillis{logicalType: logicalType}, range_opts, _global) do
    range_opts
    |> Keyword.get(String.to_atom(logicalType), [])
    |> case do
      [] -> quote(do: Constructors.datetime())
      opts -> quote(do: Constructors.datetime(unquote(opts)))
    end
  end
end
