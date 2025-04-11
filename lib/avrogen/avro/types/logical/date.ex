defmodule Avrogen.Avro.Types.Logical.Date do
  @moduledoc """
    This type represents the [date](https://avro.apache.org/docs/1.11.1/specification/_print/#date)
    type according to the specification.

    The date logical type represents a date within the calendar, with no reference to a particular time zone or time of
    day.

    A date logical type annotates an Avro int, where the int stores the number of days from the unix epoch, 1 January
    1970 (ISO calendar).
  """

  use TypedStruct

  @logical_type "date"
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

alias Avrogen.Avro.Types.Logical
alias Avrogen.Avro.Schema.CodeGenerator

defimpl CodeGenerator, for: Logical.Date do
  def external_dependencies(_), do: []

  def normalize(value, global, _parent_namespace, _scope_embedded_types), do: {value, global}

  def elixir_type(%Logical.Date{}), do: quote(do: Date.t())

  def encode_function(%Logical.Date{}, function_name, _global) do
    quote do
      defp unquote(function_name)(%Date{} = date),
        do: Date.diff(date, ~D[1970-01-01])
    end
  end

  def decode_function(%Logical.Date{}, function_name, _global) do
    quote do
      defp unquote(function_name)(date) when is_number(date),
        do: {:ok, Date.add(~D[1970-01-01], date)}

      defp unquote(function_name)(date),
        do: {:error, "Expected an integer, got: #{inspect(date)}"}
    end
  end

  def contains_pii?(%Logical.Date{}, _global), do: false

  def drop_pii(%Logical.Date{}, function_name, _global) do
    quote do
      def unquote(function_name)(%Date{}), do: Date.utc_today()
    end
  end

  def random_instance(%Logical.Date{logicalType: logicalType}, range_opts, _global) do
    range_opts
    |> Keyword.get(String.to_atom(logicalType), [])
    |> case do
      [] -> quote(do: Constructors.date())
      opts -> quote(do: Constructors.date(unquote(opts)))
    end
  end
end
