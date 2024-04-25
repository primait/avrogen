defmodule Avrogen.Avro.Types.Reference do
  @moduledoc """
    A reference to an external schema name.
  """
  use TypedStruct

  typedstruct do
    # The name of the external schema
    field :name, String.t()
  end

  def from_name(name), do: parse(name)

  def parse(name), do: %__MODULE__{name: name}

  def elixir_type_name(%__MODULE__{name: name}),
    do: name |> String.split(".") |> List.last() |> Macro.camelize()
end

alias Avrogen.Avro.Types
alias Avrogen.Avro.Types.Reference
alias Avrogen.Avro.Schema.CodeGenerator

defimpl Jason.Encoder, for: Reference do
  def encode(%Reference{name: name}, opts), do: Jason.Encode.string(name, opts)
end

defimpl CodeGenerator, for: Reference do
  def external_dependencies(%Reference{name: name}), do: [name]
  def normalize(value, global, _parent_namespace, _scope_embedded_types), do: {value, global}

  def elixir_type(%Reference{} = ref) do
    ref |> Reference.elixir_type_name() |> then(&"#{&1}.t()") |> Code.string_to_quoted!()
  end

  def encode_function(%Reference{name: name}, function_name, global) do
    case Map.get(global, name) do
      %Types.Record{} = record -> CodeGenerator.encode_function(record, function_name, global)
      %Types.Enum{} = enum -> CodeGenerator.encode_function(enum, function_name, global)
    end
  end

  def decode_function(%Reference{name: name}, function_name, global) do
    case Map.get(global, name) do
      %Types.Record{} = record -> CodeGenerator.decode_function(record, function_name, global)
      %Types.Enum{} = enum -> CodeGenerator.decode_function(enum, function_name, global)
    end
  end

  def drop_pii(%Reference{name: name}, function_name, global) do
    case Map.get(global, name) do
      %Types.Record{} = record -> CodeGenerator.drop_pii(record, function_name, global)
      %Types.Enum{} = enum -> CodeGenerator.drop_pii(enum, function_name, global)
    end
  end

  def contains_pii?(%Reference{name: name}, global) do
    case Map.get(global, name) do
      %Types.Record{} = record -> CodeGenerator.contains_pii?(record, global)
      %Types.Enum{} = enum -> CodeGenerator.contains_pii?(enum, global)
    end
  end

  def random_instance(%Reference{name: name}, range_opts, global) do
    case Map.get(global, name) do
      %Types.Record{} = record -> CodeGenerator.random_instance(record, range_opts, global)
      %Types.Enum{} = enum -> CodeGenerator.random_instance(enum, range_opts, global)
    end
  end
end
