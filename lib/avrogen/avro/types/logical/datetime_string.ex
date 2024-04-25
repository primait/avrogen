defmodule Avrogen.Avro.Types.Logical.DateTimeString do
  @moduledoc """
    This type actually does not conform to the specification for a decimal.

    However, this is in use in our code base. This type is when a string represents a
    date time value as stored as an iso8601 string.
  """
  use TypedStruct

  @logical_types ["datetime", "iso_datetime"]
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

alias Avrogen.Avro.Types.Logical.DateTimeString
alias Avrogen.Avro.Schema.CodeGenerator

defimpl CodeGenerator, for: DateTimeString do
  def external_dependencies(_), do: []

  def normalize(value, global, _parent_namespace, _scope_embedded_types), do: {value, global}

  def elixir_type(%DateTimeString{}), do: quote(do: DateTime.t())

  def encode_function(%DateTimeString{}, function_name, _global) do
    quote do
      defp unquote(function_name)(%DateTime{} = timestamp), do: DateTime.to_iso8601(timestamp)
    end
  end

  def decode_function(%DateTimeString{}, function_name, _global) do
    quote do
      defp unquote(function_name)(timestamp) do
        case DateTime.from_iso8601(timestamp) do
          {:ok, datetime, _} -> {:ok, datetime}
          {:error, error} -> {:error, error}
        end
      end
    end
  end

  def contains_pii?(%DateTimeString{}, _global), do: false

  def drop_pii(%DateTimeString{}, function_name, _global) do
    quote do
      def unquote(function_name)(%DateTime{}), do: DateTime.utc_now()
    end
  end

  def random_instance(%DateTimeString{logicalType: logicalType}, range_opts, _global) do
    range_opts
    |> Keyword.get(String.to_atom(logicalType), [])
    |> case do
      [] -> quote(do: Constructors.datetime())
      opts -> quote(do: Constructors.datetime(unquote(opts)))
    end
  end
end
