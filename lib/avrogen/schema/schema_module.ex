defmodule Avrogen.Schema.SchemaModule do
  @moduledoc """
  Common behaviour for modules that define avro schemas in code.
  """

  @doc """
  The schema's name, used for creating a file name.
  """
  @callback schema_name() :: String.t()

  # TODO: consider removing this as avro_schema_elixir is sufficient
  @doc """
  The actual schema, i.e. a json-string.
  """
  @callback avsc() :: String.t()

  @doc """
  The actual schema, but as an elixir list, so it can be 'imported' into other
  schemas.
  """
  @callback avro_schema_elixir() :: [map()]
end
