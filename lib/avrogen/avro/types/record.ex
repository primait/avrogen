alias Avrogen.Avro.Schema.CodeGenerator

defmodule Avrogen.Avro.Types.Record do
  @moduledoc """
    This type is a representation of the [Avro record type](https://avro.apache.org/docs/1.11.0/spec.html#Records).
  """

  alias Avrogen.Avro.Schema
  alias Avrogen.Avro.Types
  alias Avrogen.Avro.Types.Record.Field
  alias Avrogen.Utils.MacroUtils
  use TypedStruct

  @identifier "record"

  typedstruct do
    # A JSON string providing the name of the enum (required).
    field :name, String.t(), enforce: true
    # A JSON string that qualifies the name
    field :namespace, String.t() | nil
    # A JSON string providing documentation to the user of this schema (optional).
    field :doc, String.t() | nil
    # A JSON array of strings, providing alternate names for this enum (optional).
    field :aliases, [String.t()] | nil
    # A JSON array, listing fields (required). Each field is a JSON object with the attributes
    # described as part of the Avrogen.Avro.Types.Record.Field.
    field :fields, [Field.t()], enforce: true
    # This will always be set to "record" it is maintained to simplify the JSON encoding logic.
    field :type, String.t()
  end

  def identifier, do: @identifier

  def parse(%{"type" => @identifier, "name" => name, "fields" => fields} = record) do
    %__MODULE__{
      name: Macro.camelize(name),
      namespace: record["namespace"],
      doc: record["doc"],
      aliases: record["aliases"],
      fields: Enum.map(fields, &__MODULE__.Field.parse/1),
      type: @identifier
    }
  end

  defdelegate fullname(record, namespace), to: Avrogen.Avro.Types.Utils
  defdelegate namespace(record, namespace, scope_embedded_types), to: Avrogen.Avro.Types.Utils

  def generate_module(%__MODULE__{} = record, global, name, module_prefix) do
    quote do
      defmodule unquote(Schema.module_path(module_prefix, name, record.name)) do
        @moduledoc unquote(module_doc(record))
        @dialyzer [:no_match]

        unquote_splicing(aliases(record, module_prefix, global))

        use TypedStruct
        use Accessible

        @derive Jason.Encoder
        typedstruct do
          (unquote_splicing(Enum.map(record.fields, &__MODULE__.Field.typed_struct_field/1)))
        end

        @behaviour Avrogen.AvroModule

        @impl true
        def avro_fqn, do: unquote(name)

        @impl true
        def avro_schema_name, do: unquote(namespace_from_fqn(name))

        @impl true
        unquote(to_avro_map(record))

        @impl true
        unquote(from_avro_map(record))

        unquote_splicing(from_avro_map_invalid_clause(record))

        def from_avro_map(_) do
          {:error, "Expected a map."}
        end

        @pii_fields MapSet.new(unquote(pii_keys(record)))
        def pii_fields, do: @pii_fields

        unquote_splicing(drop_pii(record, global))

        unquote_splicing(encoding_functions(record, global))

        unquote_splicing(decoding_functions(record, global))

        defp unwrap!({:ok, value}), do: value
        defp unwrap!({:error, error}), do: raise(error)

        alias Avrogen.Util.Random
        alias Avrogen.Util.Random.Constructors

        @spec random_instance(Random.rand_state()) :: {Random.rand_state(), struct()}
        unquote(random_instance(record, global))
      end
    end
  end

  defp to_avro_map(%__MODULE__{fields: fields}) do
    fields =
      Enum.map(fields, fn field -> {field.name, __MODULE__.Field.to_avro_map_clause(field)} end)

    quote do
      def to_avro_map(%__MODULE__{} = value) do
        %{unquote_splicing(fields)}
      end
    end
  end

  defp from_avro_map(%__MODULE__{fields: fields}) do
    name =
      fields
      |> Enum.any?(&Field.has_default?/1)
      |> case do
        true -> "avro_map"
        false -> "_avro_map"
      end
      |> Code.string_to_quoted!()

    required_fields =
      fields
      |> Enum.reject(&Field.has_default?/1)
      |> Enum.map(fn field -> {field.name, Code.string_to_quoted!(field.name)} end)

    optional_fields =
      fields
      |> Enum.filter(&Field.has_default?/1)
      |> Enum.map(&Field.bind_with_default/1)

    record_fields =
      Enum.map(fields, fn field ->
        {String.to_atom(field.name), __MODULE__.Field.from_avro_map_clause(field)}
      end)

    quote do
      def from_avro_map(%{unquote_splicing(required_fields)} = unquote(name)) do
        unquote_splicing(optional_fields)

        {:ok, %__MODULE__{unquote_splicing(record_fields)}}
      end
    end
  end

  defp from_avro_map_invalid_clause(record) do
    required_keys = required_keys(record)

    case required_keys do
      [] ->
        quote do
        end

      _ ->
        quote do
          @required_keys MapSet.new(unquote(required_keys))
          def from_avro_map(%{} = invalid) do
            actual = Map.keys(invalid) |> MapSet.new()
            missing = MapSet.difference(@required_keys, actual) |> Enum.join(", ")
            {:error, "Missing keys: " <> missing}
          end
        end
    end
    |> MacroUtils.flatten_block()
  end

  defp encoding_functions(%__MODULE__{fields: fields}, global) do
    fields
    |> Enum.map(&CodeGenerator.encode_function(&1, nil, global))
    |> MacroUtils.flatten_block()
  end

  defp decoding_functions(%__MODULE__{fields: fields}, global) do
    fields
    |> Enum.map(&CodeGenerator.decode_function(&1, nil, global))
    |> MacroUtils.flatten_block()
  end

  defp namespace_from_fqn(fqn) do
    fqn
    |> String.split(".")
    |> Enum.drop(-1)
    |> Enum.join(".")
  end

  defp required_keys(%__MODULE__{fields: fields}) do
    fields
    |> Enum.reject(&Field.has_default?/1)
    |> Enum.map(&Field.name/1)
  end

  defp pii_keys(%__MODULE__{fields: fields}) do
    fields
    |> Enum.filter(&Field.is_pii?/1)
    |> Enum.map(&Field.name/1)
  end

  defp drop_pii(%__MODULE__{fields: fields}, global) do
    may_contain_pii = Enum.filter(fields, &CodeGenerator.contains_pii?(&1, global))
    clauses = Enum.map(may_contain_pii, &drop_pii_clauses/1)

    functions =
      may_contain_pii
      |> Enum.map(&CodeGenerator.drop_pii(&1, nil, global))
      |> MacroUtils.flatten_block()

    case may_contain_pii do
      [] ->
        quote do
          def drop_pii(%__MODULE__{} = value), do: value
        end

      _ ->
        quote do
          def drop_pii(%__MODULE__{} = value) do
            value = Map.from_struct(value)
            unquote_splicing(clauses)
            Kernel.struct(__MODULE__, value)
          end

          unquote_splicing(functions)
        end
    end
    |> MacroUtils.flatten_block()
  end

  defp drop_pii_clauses(%Field{
         name: name,
         pii: true,
         type: %Types.Union{types: [%Types.Primitive{type: :null} | _]}
       }) do
    name = String.to_atom(name)
    quote(do: value = Map.replace!(value, unquote(name), nil))
  end

  defp drop_pii_clauses(%Field{name: name} = field) do
    name = String.to_atom(name)
    function_name = field |> Field.drop_pii_function_name()
    quote(do: value = Map.update!(value, unquote(name), &(__MODULE__.unquote(function_name) / 1)))
  end

  defp random_instance(%__MODULE__{fields: fields}, global) do
    random_instances =
      Enum.map(fields, fn field ->
        name = String.to_atom(field.name)

        {name, CodeGenerator.random_instance(field, [], global)}
      end)

    quote do
      def random_instance(rand_state) do
        Constructors.instantiate(rand_state, __MODULE__, [
          unquote_splicing(random_instances)
        ])
      end
    end
  end

  defp aliases(%__MODULE__{} = record, module_prefix, global) do
    record
    |> Schema.external_dependencies()
    |> Enum.map(&Schema.module_path(module_prefix, &1, global))
    |> Enum.sort()
    |> Enum.map(fn module -> quote(do: alias(unquote(module))) end)
  end

  defp module_doc(%__MODULE__{doc: doc, fields: fields}) do
    field_docs = Enum.map_join(fields, "\n    ", &Field.comment/1)

    """
      #{doc || ""}

      This module was automatically generated from an AVRO schema.

      Fields:
        #{field_docs}
    """
  end
end

alias Avrogen.Avro.Types.Record
alias Avrogen.Avro.Types

defimpl CodeGenerator, for: Record do
  def external_dependencies(%Record{fields: fields}),
    do: Enum.flat_map(fields, &CodeGenerator.external_dependencies/1)

  def normalize(%Record{fields: fields} = record, global, parent_namespace, scope_embedded_types) do
    name = Record.fullname(record, parent_namespace)
    parent_namespace = Record.namespace(record, parent_namespace, scope_embedded_types)

    {fields, global} =
      Enum.reduce(fields, {[], global}, fn field, {fields, global} ->
        {updated_schema, global} =
          CodeGenerator.normalize(field, global, parent_namespace, scope_embedded_types)

        {[updated_schema | fields], global}
      end)

    value = %Record{record | fields: Enum.reverse(fields), namespace: parent_namespace}

    {Types.Reference.from_name(name), Map.put_new(global, name, value)}
  end

  def elixir_type(%Record{name: name}), do: quote(do: unquote(name).t())

  def encode_function(%Record{name: name}, function_name, _global) do
    type_name = Code.string_to_quoted!(name)

    quote do
      defp unquote(function_name)(%unquote(type_name){} = value) do
        unquote(type_name).to_avro_map(value)
      end
    end
  end

  def decode_function(%Record{name: name}, function_name, _global) do
    name = Code.string_to_quoted!(name)

    quote do
      defp unquote(function_name)(value), do: unquote(name).from_avro_map(value)
    end
  end

  def contains_pii?(%Record{}, _global), do: true

  def drop_pii(%Record{name: name}, function_name, _global) do
    name = Code.string_to_quoted!(name)

    quote do
      def unquote(function_name)(%unquote(name){} = value), do: unquote(name).drop_pii(value)
    end
  end

  def random_instance(%Record{name: name}, _range_opts, _global) do
    name = Code.string_to_quoted!(name)
    quote(do: &unquote(name).random_instance/1)
  end
end
