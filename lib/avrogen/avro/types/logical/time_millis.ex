defmodule Avrogen.Avro.Types.Logical.TimeMillis do
  @moduledoc """
    This type represents the [time-millis](https://avro.apache.org/docs/1.11.1/specification/_print/#time-millisecond-precision)
    type according to the specification

    The time-millis logical type represents a time, with no reference to a particular calendar or time zone,
    with a precision of one millisecond.

    A time-millis logical type annotates an Avro int, where the int stores the number of
    milliseconds after midnight, 00:00:00.000.
  """

  use TypedStruct

  @logical_type "time-millis"
  @avro_type "int"

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

alias Avrogen.Avro.Types.Logical.TimeMillis
alias Avrogen.Avro.Schema.CodeGenerator

defimpl CodeGenerator, for: TimeMillis do
  def external_dependencies(_), do: []

  def normalize(value, global, _parent_namespace, _scope_embedded_types), do: {value, global}

  def elixir_type(%TimeMillis{}), do: quote(do: Time.t())

  def encode_function(%TimeMillis{}, function_name, _global) do
    quote do
      defp unquote(function_name)(%Time{} = time),
        do: Time.diff(time, ~T[00:00:00.000], :millisecond)
    end
  end

  def decode_function(%TimeMillis{}, function_name, _global) do
    quote do
      defp unquote(function_name)(time) when is_number(time),
        do: {:ok, Time.add(~T[00:00:00.000], time, :millisecond)}

      defp unquote(function_name)(time),
        do: {:error, "Expected an int value, got: #{inspect(time)}"}
    end
  end

  def contains_pii?(%TimeMillis{}, _global), do: false

  def drop_pii(%TimeMillis{}, function_name, _global) do
    quote do
      def unquote(function_name)(%Time{}), do: Time.utc_now()
    end
  end

  def random_instance(%TimeMillis{logicalType: logicalType}, range_opts, _global) do
    range_opts
    |> Keyword.get(String.to_atom(logicalType), [])
    |> case do
      [] -> quote(do: Constructors.time())
      opts -> quote(do: Constructors.time(unquote(opts)))
    end
  end
end
