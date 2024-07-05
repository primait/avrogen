defmodule Avrogen.Avro.Types.Logical.DateString do
  @moduledoc """
    This type actually does not conform to the specification for a date.

    However, this is in use in our code base. This type is when a string represents a
    date value as stored as an iso8601 string.
  """
  use TypedStruct

  @logical_types ["date", "iso_date"]
  @identifier "string"

  @derive Jason.Encoder
  typedstruct do
    # This will always be set to one of the @logical_types it is maintained to simplify
    # the JSON encoding logic.
    field :logicalType, String.t()
    # This will always be set to @identifier it is maintained to simplify the JSON encoding logic.
    field :type, String.t()
  end

  def parse(%{"logicalType" => logical_type, "type" => @identifier})
      when logical_type in @logical_types,
      do: %__MODULE__{logicalType: logical_type, type: @identifier}
end

alias Avrogen.Avro.Types.Logical.DateString
alias Avrogen.Avro.Schema.CodeGenerator

defimpl CodeGenerator, for: DateString do
  def external_dependencies(_), do: []

  def normalize(value, global, _parent_namespace, _scope_embedded_types), do: {value, global}

  def elixir_type(%DateString{}), do: quote(do: Date.t())

  def encode_function(%DateString{}, function_name, _global) do
    quote do
      defp unquote(function_name)(%Date{} = date), do: Date.to_iso8601(date)
    end
  end

  def decode_function(%DateString{}, function_name, _global) do
    quote do
      defp unquote(function_name)(date), do: Date.from_iso8601(date)
    end
  end

  def contains_pii?(%DateString{}, _global), do: false

  def drop_pii(%DateString{}, function_name, _global) do
    quote do
      def unquote(function_name)(%Date{}), do: Date.utc_today()
    end
  end

  def random_instance(%DateString{logicalType: logicalType}, range_opts, _global) do
    range_opts
    |> Keyword.get(String.to_atom(logicalType), [])
    |> case do
      [] -> quote(do: Constructors.date())
      opts -> quote(do: Constructors.date(unquote(opts)))
    end
  end
end
