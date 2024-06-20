defmodule Avrogen.Avro.Schema do
  @moduledoc """
    The entry point for code generation. It starts by taking a raw schema: JSON matching the
    [specification](https://avro.apache.org/docs/1.11.0/spec.html#schemas).

    An Avro schema is a recursive data structure.
  """

  alias Avrogen.Avro.Schema.CodeGenerator
  alias Avrogen.Avro.Types
  import Types.Primitive, only: [is_primitive: 1]

  @type raw_schema :: map() | [map()]

  @type non_union ::
          Types.Record.t()
          | Types.Record.Field.t()
          | Types.Reference.t()
          | Types.Primitive.t()
          | Types.Logical.t()
          | Types.Enum.t()
          | Types.Map.t()
          | Types.Array.t()
  @type t :: Types.Union.t() | non_union()
  @type generated_code :: iodata()
  @type file_name :: String.t()

  @spec parse(raw_schema()) :: t()
  def parse(value) when is_primitive(value), do: Types.Primitive.parse(value)
  def parse(value) when is_binary(value), do: Types.Reference.parse(value)
  def parse(value) when is_list(value), do: Types.Union.parse(value)
  def parse(%{"type" => "record"} = value), do: Types.Record.parse(value)
  def parse(%{"type" => "enum"} = value), do: Types.Enum.parse(value)
  def parse(%{"type" => "array"} = value), do: Types.Array.parse(value)
  def parse(%{"type" => "map"} = value), do: Types.Map.parse(value)
  def parse(%{"logicalType" => _} = value), do: Types.Logical.parse(value)

  @doc """
    This function will generate elixir modules for the provided schema. If the schema
    references external types (i.e. types that are not embedded within the schema),
    then the schemas for the external dependencies should be passed as the second
    argument.

    Overview of code:

    - This function works by first parsing the schemas into `Schema.t()` which is a recursive
      data structure representing the avro schema file.
    - It then does a second parse over the schema where it normalizes the schema by extracting
      all the embedded types and replacing the embedded type with a reference to the schema.
    - The final stage is generation of the specific modules (for `enum`s and 'record`s).
      The code generation relies on the 'CodeGenerator` protocol defined below where each
      part of the schema implements this protocol and is responsible for generating snippets
      of the generated code. These snippets are combined the `CodeGenerator` implementation in
      the patent type.
  """
  @spec generate_code(raw_schema(), raw_schema(), String.t() | nil, Keyword.t()) ::
          [{file_name(), generated_code()}]
  def generate_code(schema, dependencies, module_prefix, opts \\ []) do
    scope_embedded_types = Keyword.get(opts, :scope_embedded_types, false)
    dest = Keyword.get(opts, :dest, "")

    {_, schemas} = schema |> parse() |> CodeGenerator.normalize(%{}, nil, scope_embedded_types)
    {_, global} = dependencies |> parse() |> CodeGenerator.normalize(schemas, nil)

    Enum.map(schemas, fn {name, schema} ->
      filename = filename_from_schema(dest, schema)

      code =
        schema
        |> generate_module(global, name, module_prefix)
        |> Macro.to_string()
        |> Code.format_string!(locals_without_parens: [field: 2, field: 3], file: filename)

      {filename, [code, ?\n]}
    end)
  end

  @spec normalized_schemas(raw_schema(), String.t() | nil, boolean()) :: [t()]
  def normalized_schemas(schema, module_prefix, scope_embedded_types) do
    schema
    |> parse()
    |> CodeGenerator.normalize(%{}, module_prefix, scope_embedded_types)
    |> Kernel.elem(1)
    |> Enum.map(&Kernel.elem(&1, 1))
  end

  @doc """
    Get all the filenames of the generated elixir source file from a schema.
  """
  @spec filenames_from_schema(Path.t(), raw_schema(), Keyword.t()) :: [Path.t()]
  def filenames_from_schema(dest, schema, opts \\ []) do
    scope_embedded_types = Keyword.get(opts, :scope_embedded_types, false)

    schema
    |> normalized_schemas(nil, scope_embedded_types)
    |> Enum.map(&filename_from_schema(dest, &1))
  end

  def external_dependencies(schema) do
    schema
    |> CodeGenerator.external_dependencies()
    |> MapSet.new()
    |> Enum.sort()
  end

  @doc """
    Get the filename of the generated elixir source file from a schema.
  """
  @spec filename_from_schema(Path.t(), Types.Record.t() | Types.Enum.t()) :: Path.t()
  def filename_from_schema(dest, schema) do
    dest
    |> Path.join(String.replace(schema.namespace || "", ".", "/"))
    |> Path.join(Macro.underscore(schema.name) <> ".ex")
  end

  defp generate_module(%Types.Record{} = record, global, name, module_prefix),
    do: Types.Record.generate_module(record, global, name, module_prefix)

  defp generate_module(%Types.Enum{} = enum, _global, name, module_prefix),
    do: Types.Enum.generate_module(enum, module_path(module_prefix, name, enum.name))

  def module_path(module_prefix, dep_name, %{} = global) do
    case Map.get(global, dep_name) do
      %{name: name} -> module_path(module_prefix, dep_name, name)
      _ -> raise "Unknown schema reference #{dep_name}"
    end
  end

  def module_path(module_prefix, dep_name, name) when is_binary(name) do
    path = dep_name |> String.split(".") |> Enum.drop(-1) |> Enum.concat([name])

    module_prefix
    |> String.split(".")
    |> Enum.concat(path)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&Macro.camelize/1)
    |> Module.concat()
  end
end

defprotocol Avrogen.Avro.Schema.CodeGenerator do
  @moduledoc """
    Protocol defining how different types representing an Avro schema should contribute
    to the code generation process.
  """

  alias Avrogen.Avro.Schema

  @type global :: %{String.t() => Schema.t()}
  @type parent_namespace :: String.t() | nil
  @type scoped_embedded_types :: boolean()

  @doc """
    Extract the external dependencies fro this schema.
  """
  @spec external_dependencies(Schema.t()) :: [String.t()]
  def external_dependencies(value)

  @doc """
    Normalizes the schema by extracting all embedded schemas into `global` and returning the
    schema with the embedded types replaced with references to their global names.
  """
  @spec normalize(Schema.t(), global(), parent_namespace(), scoped_embedded_types()) ::
          {Schema.t(), global()}
  def normalize(value, global, parent_namespace, scope_embedded_types \\ false)

  @doc """
    Returns the elixir type spec for this Avro schema type.
  """
  @spec elixir_type(Schema.t()) :: Macro.t()
  def elixir_type(value)

  @doc """
    Returns the function responsible for encoding the value to an avro map

    This should return a function with an infallible return type
  """
  @spec encode_function(Schema.t(), atom(), global()) :: Macro.t()
  def encode_function(value, function_name, global)

  @doc """
    Returns the function responsible decoding the value from an avro map.

    Note the returned function should have a return type as a result tuple.
  """
  @spec decode_function(Schema.t(), atom(), global()) :: Macro.t()
  def decode_function(value, function_name, global)

  @doc """
    Returns whether this type contains any PII including any PII in nested types.
  """
  @spec contains_pii?(Schema.t(), global()) :: boolean()
  def contains_pii?(value, global)

  @doc """
    Returns the function for dropping the the PII values stored in this type.
  """
  @spec drop_pii(Schema.t(), atom(), global()) :: Macro.t()
  def drop_pii(value, function_name, global)

  @doc """
    Returns the snippet of code responsible for generating a random instance of this type.
  """
  @spec random_instance(Schema.t(), Keyword.t(), global()) :: Macro.t()
  def random_instance(value, range_opts, global)
end
