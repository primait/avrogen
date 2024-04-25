defmodule Avrogen.Avro.Types.Enum do
  @moduledoc """
    This type is a representation of the [Avro Enum type](https://avro.apache.org/docs/1.11.0/spec.html#Enums).
  """
  alias Avrogen.Utils.MacroUtils

  use TypedStruct
  @identifier "enum"

  typedstruct do
    # A JSON string providing the name of the enum (required).
    field :name, String.t(), enforce: true
    # A JSON string that qualifies the name
    field :namespace, String.t() | nil
    # A JSON array of strings, providing alternate names for this enum (optional).
    field :aliases, [String.t()]
    # A JSON string providing documentation to the user of this schema (optional).
    field :doc, String.t() | nil
    # A JSON array, listing symbols, as JSON strings (required). All symbols in an enum must be
    # unique; duplicates are prohibited. Every symbol must match the regular expression
    # [A-Za-z_][A-Za-z0-9_]* (the same requirement as for names).
    field :symbols, [String.t()], enforce: true
    # A default value for this enumeration, used during resolution when the reader
    # encounters a symbol from the writer that isn't defined in the reader's schema (optional).
    # The value provided here must be a JSON string that's a member of the symbols array.
    # See documentation on schema resolution for how this gets used.
    field :default, String.t() | nil
    # **This is not part of the Avro spec**
    field :preferred_subset, [String.t()] | nil
    # This will always be set to "enum" it is maintained to simplify the JSON encoding logic.
    field :type, String.t()
  end

  def parse(%{"type" => @identifier, "name" => name, "symbols" => symbols} = enum) do
    %__MODULE__{
      name: Macro.camelize(name),
      namespace: enum["namespace"],
      aliases: enum["aliases"],
      doc: enum["doc"],
      symbols: symbols,
      default: enum["default"],
      preferred_subset: enum["preferred_subset"],
      type: @identifier
    }
  end

  defdelegate fullname(record, namespace), to: Avrogen.Avro.Types.Utils
  defdelegate namespace(record, namespace, scope_embedded_types), to: Avrogen.Avro.Types.Utils

  def constructor_functions(symbols) do
    symbols
    |> Enum.map(fn symbol ->
      function_name = :"_#{symbol}"
      variant = String.to_atom(symbol)

      quote do
        @spec unquote(function_name)() :: unquote(variant)
        def unquote(function_name)(), do: unquote(variant)
      end
    end)
    |> MacroUtils.flatten_block()
  end

  # credo:disable-for-next-line
  def generate_module(%__MODULE__{} = enum, module_path) do
    quote do
      defmodule unquote(module_path) do
        @moduledoc unquote(module_doc(enum))

        @typedoc unquote(type_doc(enum))
        @type t() :: unquote(type(enum))
        @values MapSet.new(unquote(values(enum)))
        @values_string MapSet.new(unquote(enum.symbols))

        def values, do: @values

        unquote(preferred_subset(enum))

        @spec value(atom() | binary()) :: {:ok, atom()} | {:error, any()}
        def value(a) when is_atom(a), do: do_value(a, @values)
        def value(s) when is_binary(s), do: do_value(s, @values_string)

        def value(other) do
          {:error, "Input #{inspect(other)} has invalid type (expected atom or string)"}
        end

        defp do_value(value, accepted_values) do
          case MapSet.member?(accepted_values, value) do
            true -> {:ok, ensure_atom!(value)}
            false -> {:error, "#{inspect(value)} is not a value of " <> unquote(enum.name)}
          end
        end

        def ensure_atom!(value) when is_atom(value), do: value
        def ensure_atom!(value) when is_binary(value), do: String.to_atom(value)

        def value!(s), do: s |> value() |> unwrap!()

        unquote_splicing(constructor_functions(enum.symbols))

        defp unwrap!({:ok, value}), do: value
        defp unwrap!({:error, error}), do: raise(error)

        alias Avrogen.Util.FuzzyEnumMatch
        @index FuzzyEnumMatch.make_index(@values)
        @spec best_fuzzy_match(String.t(), atom(), number()) :: atom()
        def best_fuzzy_match(string, default_value, minimum_similarity \\ 0.5) do
          FuzzyEnumMatch.best_match(@index, string, default_value, minimum_similarity)
        end
      end
    end
  end

  defp values(%__MODULE__{symbols: symbols}), do: Enum.map(symbols, &String.to_atom/1)

  defp type_doc(%__MODULE__{name: name}), do: "Enum values for #{name}."

  defp module_doc(%__MODULE__{doc: nil}), do: ""

  defp module_doc(%__MODULE__{doc: doc}),
    do: """
      #{doc}
    """

  defp type(%__MODULE__{} = enum) do
    enum
    |> values()
    |> Enum.map_join(" | ", &Macro.to_string/1)
    |> Code.string_to_quoted!()
  end

  defp preferred_subset(%__MODULE__{preferred_subset: nil}) do
    quote do
      def preferred_values, do: @values
    end
  end

  defp preferred_subset(%__MODULE__{preferred_subset: preferred_subset}) do
    preferred_subset = Enum.map(preferred_subset, &String.to_atom/1)

    quote do
      @preferred_subset MapSet.new(unquote(preferred_subset))
      def preferred_values, do: @preferred_subset
    end
  end
end

alias Avrogen.Avro.Types
alias Avrogen.Avro.Types.Enum
alias Avrogen.Avro.Schema.CodeGenerator

defimpl CodeGenerator, for: Enum do
  def external_dependencies(_value), do: []

  def normalize(%Enum{} = value, global, parent_namespace, scope_embedded_types) do
    name = Enum.fullname(value, parent_namespace)
    parent_namespace = Enum.namespace(value, parent_namespace, scope_embedded_types)

    value = %Enum{value | namespace: parent_namespace}

    {Types.Reference.from_name(name), Map.put_new(global, name, value)}
  end

  def elixir_type(%Enum{name: name}), do: quote(do: unquote(name).t())

  def encode_function(%Enum{}, function_name, _global) do
    quote do
      defp unquote(function_name)(value) when is_atom(value) and not is_nil(value),
        do: Atom.to_string(value)
    end
  end

  def decode_function(%Enum{name: name}, function_name, _global) do
    type_name = Code.string_to_quoted!(name)

    quote do
      defp unquote(function_name)(value), do: unquote(type_name).value(value)
    end
  end

  def contains_pii?(%Enum{}, _global), do: false

  def drop_pii(%Enum{default: nil}, function_name, _global) do
    quote do
      def unquote(function_name)(value) when is_atom(value) and not is_nil(value),
        do: raise("Cannot drop pii in enum without a default value")
    end
  end

  def drop_pii(%Enum{name: name, default: default}, function_name, _global) do
    type_name = Code.string_to_quoted!(name)

    quote do
      def unquote(function_name)(value) when is_atom(value) and not is_nil(value),
        do: unquote(type_name).value!(unquote(default))
    end
  end

  def random_instance(%Enum{name: name}, _range_opts, _global) do
    name = Code.string_to_quoted!(name)
    quote(do: Constructors.enum_value(unquote(name)))
  end
end
