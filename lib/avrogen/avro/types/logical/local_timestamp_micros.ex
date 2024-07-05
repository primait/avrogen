defmodule Avrogen.Avro.Types.Logical.LocalTimestampMicros do
  @moduledoc """
    This type represents the [local-timestamp-micros](https://avro.apache.org/docs/1.11.1/specification/_print/#local-timestamp-microsecond-precision)
    type according to the specification

    The timestamp-micros logical type represents a time of day, with no reference to a particular
    calendar, time zone or date, with a precision of one microsecond.

    A timestamp-micros logical type annotates an Avro long, where the long stores the number of
    microseconds after midnight, 00:00:00.000.
  """

  use TypedStruct

  @logical_type "local-timestamp-micros"
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

alias Avrogen.Avro.Types.Logical.LocalTimestampMicros
alias Avrogen.Avro.Schema.CodeGenerator

defimpl CodeGenerator, for: LocalTimestampMicros do
  def external_dependencies(_), do: []

  def normalize(value, global, _parent_namespace, _scope_embedded_types), do: {value, global}

  def elixir_type(%LocalTimestampMicros{}), do: quote(do: NaiveDateTime.t())

  def encode_function(%LocalTimestampMicros{}, function_name, _global) do
    quote do
      defp unquote(function_name)(%NaiveDateTime{} = timestamp),
        do: Timex.diff(timestamp, ~N[1970-01-01 00:00:00.000000], :microsecond)
    end
  end

  def decode_function(%LocalTimestampMicros{}, function_name, _global) do
    quote do
      defp unquote(function_name)(timestamp) when is_number(timestamp),
        do:
          {:ok,
           Timex.add(~N[1970-01-01 00:00:00.000000], Timex.Duration.from_microseconds(timestamp))}

      defp unquote(function_name)(timestamp),
        do: {:error, "Expected a long value, got: #{inspect(timestamp)}"}
    end
  end

  def contains_pii?(%LocalTimestampMicros{}, _global), do: false

  def drop_pii(%LocalTimestampMicros{}, function_name, _global) do
    quote do
      def unquote(function_name)(%NaiveDateTime{}), do: NaiveDateTime.utc_now()
    end
  end

  def random_instance(%LocalTimestampMicros{logicalType: logicalType}, range_opts, _global) do
    range_opts
    |> Keyword.get(String.to_atom(logicalType), [])
    |> case do
      [] -> quote(do: Constructors.datetime())
      opts -> quote(do: Constructors.datetime(unquote(opts)))
    end
  end
end
