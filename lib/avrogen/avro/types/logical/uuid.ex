defmodule Avrogen.Avro.Types.Logical.UUID do
  @moduledoc """
    This represents the logical type of the [uuid](https://avro.apache.org/docs/1.11.1/specification/_print/#uuid)
    in the specification.

    The uuid logical type represents a random generated universally unique identifier (UUID).

    A uuid logical type annotates an Avro string. The string has to conform with RFC-4122
  """
  use TypedStruct
  @logical_type "uuid"
  @avro_type "string"

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

defimpl CodeGenerator, for: Logical.UUID do
  def external_dependencies(_), do: []

  def normalize(value, global, _parent_namespace, _scope_embedded_types), do: {value, global}

  def elixir_type(%Logical.UUID{}), do: quote(do: String.t())

  def encode_function(%Logical.UUID{}, function_name, _global) do
    quote do
      defp unquote(function_name)(uuid) when is_binary(uuid) do
        case UUID.info(uuid) do
          {:ok, _} -> uuid
          {:error, error} -> raise ArgumentError, message: inspect(error)
        end
      end
    end
  end

  def decode_function(%Logical.UUID{}, function_name, _global) do
    quote do
      defp unquote(function_name)(uuid) do
        case UUID.info(uuid) do
          {:ok, _} -> {:ok, uuid}
          {:error, error} -> {:error, error}
        end
      end
    end
  end

  def contains_pii?(%Logical.UUID{}, _global), do: false

  def drop_pii(%Logical.UUID{}, function_name, _global) do
    quote do
      def unquote(function_name)(value) when is_binary(value), do: UUID.uuid4()
    end
  end

  def random_instance(%Logical.UUID{}, _range_opts, _global), do: quote(do: Constructors.uuid())
end
