defmodule Avrogen.AvroModule do
  @moduledoc """
  Behaviour for generated record modules.
  """

  @doc """
  Turn a (nested) struct (as defined by the generated avro modules) into an
  intermediate map that can be passed to a suitable erlavro encoder.
  """
  @callback to_avro_map(map()) :: map()

  @doc """
  Turn a raw map from an erlavro decoding operation into (nested) structs as
  defined by the generated avro modules.
  """
  @callback from_avro_map(map()) :: {:ok, map()} | {:error, any()}

  @doc """
  The fully qualified avro name of this record type.
  """
  @callback avro_fqn() :: String.t()

  @doc """
  The name of the schema that defines the record represented by this module.
  """
  @callback avro_schema_name() :: String.t()
end
