defmodule Avrogen.Avro.Types.Logical.DurationString do
  @moduledoc """
    This type does not conform to the Avro duration specification.

    This is useful when the Avro value is stored as an ISO 8601 duration string,
    but the generated Elixir type should be `Duration`.
  """

  use TypedStruct

  @logical_type "duration_string"
  @avro_type "string"

  @derive Jason.Encoder
  typedstruct do
    # This will always be set to @logical_type it is maintained to simplify the JSON encoding logic.
    field :logicalType, String.t()
    # This will always be set to @avro_type it is maintained to simplify the JSON encoding logic.
    field :type, String.t()
  end

  def parse(%{"logicalType" => @logical_type, "type" => @avro_type}),
    do: %__MODULE__{logicalType: @logical_type, type: @avro_type}
end

alias Avrogen.Avro.Schema.CodeGenerator
alias Avrogen.Avro.Types.Logical.DurationString

defimpl CodeGenerator, for: DurationString do
  def external_dependencies(_), do: []

  def normalize(value, global, _parent_namespace, _scope_embedded_types), do: {value, global}

  def elixir_type(%DurationString{}), do: quote(do: Duration.t())

  def encode_function(%DurationString{}, function_name, _global) do
    quote do
      defp unquote(function_name)(%Duration{} = duration),
        do: Duration.to_iso8601(duration)
    end
  end

  def decode_function(%DurationString{}, function_name, _global) do
    quote do
      defp unquote(function_name)(duration), do: Duration.from_iso8601(duration)
    end
  end

  def contains_pii?(%DurationString{}, _global), do: false

  def drop_pii(%DurationString{}, function_name, _global) do
    quote do
      def unquote(function_name)(%Duration{}), do: Duration.new!([])
    end
  end

  def random_instance(%DurationString{}, _range_opts, _global),
    do: quote(do: Constructors.duration())
end
