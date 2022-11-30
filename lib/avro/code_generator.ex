defmodule Avro.CodeGenerator do
  @moduledoc """
  Generates Elixir modules for a given Avro schema. Currently fairly specific to
  application data v2, but should evolve over time...
  """
  require EEx
  alias Avro.Schema

  defp derive_module_prefix(prefix, fqn) do
    namespace =
      fqn
      |> String.split(".")
      |> Enum.drop(-1)

    # TODO remove invalid characters from module name
    prefix_parts =
      prefix
      |> String.split(".")
      |> Enum.map(fn str -> String.trim(str) end)
      |> Enum.reject(fn str -> str == "" end)

    (prefix_parts ++ namespace)
    |> Enum.map_join(".", fn p -> Macro.camelize(p) end)
  end

  defp derive_namespace_from_fqn(fqn) do
    fqn
    |> String.split(".")
    |> Enum.drop(-1)
    |> Enum.join(".")
  end

  @doc """
  Get the filename of the generated elixir source file from a schema.
  """
  @spec filename_from_schema(Path.t(), Schema.schema()) :: Path.t()
  def filename_from_schema(dest, schema) do
    dest
    |> Path.join(String.replace(Schema.namespace(schema), ".", "/"))
    |> Path.join(Macro.underscore(Schema.name(schema)) <> ".ex")
  end

  @doc """
  For a given schema, generate the equivalent elixir source code.

  The schema can be the raw map loaded from json.
  The dependencies are a list of other schemas that this schema depends on
  This function returns the elixir code as a string.
  """
  @spec generate_schema(map(), [map()], String.t()) :: String.t()
  def generate_schema(schema, dependencies, module_prefix) do
    # Extract all the embedded fields into a single list of schemas (topologically sorted?)
    # get a map of what enums/records need to be generated / referenced
    # (will rewrite records that have inlined enum types)
    schemas = traverse(schema, %{}, nil)
    global = traverse(dependencies, schemas, nil)

    schemas
    |> Enum.map_join(fn {avro_fqn, schema} ->
      emit_code(schema, global, avro_fqn, module_prefix)
    end)
    |> String.trim()
    |> format_or_log(Avro.Schema.fqn(schema))
  end

  def format_or_log(code_string, filename) do
    try do
      Code.format_string!(code_string, locals_without_parens: [field: 2, field: 3], file: filename)
    rescue
      e ->
        IO.puts("Failed while formatting #{inspect(code_string)}")
        reraise e, __STACKTRACE__
    end
    |> IO.iodata_to_binary()
  end

  def records_and_enums_to_csv(records) do
    records
    |> Enum.flat_map(fn {_, record} -> to_csv(record) end)
  end

  def to_csv(%{type: :record, name: name, schema: schema}) do
    [["record", name, schema["doc"]]] ++
      Enum.map(schema["fields"], &record_field_csv_fields/1) ++ [[]]
  end

  def to_csv(%{type: :enum, name: name, schema: schema}) do
    [["enum", name, schema["doc"]]] ++
      Enum.map(schema["symbols"], fn s -> [nil, nil, nil, s] end) ++ [[]]
  end

  def to_csv(_other) do
    []
  end

  def record_field_csv_fields(field) do
    [
      nil,
      nil,
      nil,
      field["name"],
      typedstruct_field_type(field),
      enforce(field["type"]),
      field["doc"]
    ]
  end

  def emit_code(schema, global, avro_fqn, module_prefix) do
    do_emit_code(schema, global, avro_fqn, module_prefix)
  end

  def do_emit_code(
        %{type: :record, name: name, schema: schema, referenced_schemas: referenced},
        global,
        avro_fqn,
        module_prefix
      ) do
    alias_list =
      Enum.map(referenced, fn fqn ->
        if global[fqn] == nil do
          raise "Nothing known about #{fqn}."
        end

        derive_module_prefix(module_prefix, fqn) <> "." <> Map.get(global[fqn], :name)
      end)
      |> Enum.sort()

    emit_record(
      derive_module_prefix(module_prefix, avro_fqn),
      name,
      alias_list,
      schema["fields"],
      global,
      schema["doc"] || "",
      avro_fqn
    )
  end

  def do_emit_code(
        %{type: :enum, name: name, schema: schema},
        _global,
        avro_fqn,
        module_prefix
      ) do
    emit_enum(derive_module_prefix(module_prefix, avro_fqn), name, schema, schema["doc"] || "")
  end

  def do_emit_code(_schema, _global, _module_prefix) do
    raise "not yet implemented"
  end

  EEx.function_from_string(
    :def,
    :emit_enum,
    """
    defmodule <%= module_name_prefix %>.<%= name %> do
      @moduledoc \"\"\"
      <%= indent(moduledoc, 2) %>
      \"\"\"
      # credo:disable-for-this-file
      @dialyzer [:no_opaque, :no_return]

      @typedoc "Enum values for <%= name %>."
      @type t() :: <%= schema["symbols"] |> Enum.map(fn m -> ":\'" <> m <> "\'" end) |> Enum.join(" | ") %>

      @values [<%= schema["symbols"] |> Enum.map(fn m -> ":\'" <> m <> "\'" end) |> Enum.join(", ") %>] |> MapSet.new()

      def values(), do: @values

      <%= if schema["preferred_subset"] == nil do %>
      def preferred_values(), do: @values
      <% else %>
      @preferred_values [<%= schema["preferred_subset"] |> Enum.map(fn m -> ":\'" <> m <> "\'" end) |> Enum.join(", ") %>] |> MapSet.new()
      def preferred_values(), do: @preferred_values
      <% end %>

      @spec value(atom() | binary()) :: {:ok, atom()} | {:error, any()}
      def value(a) when is_atom(a) do
        if MapSet.member?(@values, a) do
          {:ok, a}
        else
          {:error, "\#\{inspect(a)\} is not a value of <%= name %>"}
        end
      end

      def value(s) when is_binary(s) do
        s
        |> Noether.Either.try(&String.to_existing_atom/1)
        |> Noether.Either.bind(&value/1)
      end

      def value(other) do
        {:error, "Input \#\{inspect(other)\} has invalid type (expected atom or string)"}
      end

      <%= for symbol <- schema["symbols"] do %>
      @spec _<%= symbol %>() :: <%=  ":\'" <> symbol <> "\'" %>
      def _<%= symbol %>(), do: <%=  ":\'" <> symbol <> "\'" %>
      <% end %>

      @index Avro.Util.FuzzyEnumMatch.make_index(@values)

      @spec best_fuzzy_match(String.t(), atom(), number()) :: atom()
      def best_fuzzy_match(string, default_value, minimum_similarity \\\\ 0.5) do
        Avro.Util.FuzzyEnumMatch.best_match(@index, string, default_value, minimum_similarity)
      end
    end
    """,
    [:module_name_prefix, :name, :schema, :moduledoc]
  )

  EEx.function_from_string(
    :def,
    :emit_record,
    """
    defmodule <%= module_name_prefix %>.<%= name %> do
      @moduledoc \"\"\"
      <%= indent(moduledoc, 2) %>

      Fields:
      <%= for field <- fields do %><%= field_comment(field, 4) %>
      <% end %>
      \"\"\"

      # This module was automatically generated from an AVRO schema.
      #
      # On occasion, the generated code exceeds Credo's complexity limits.
      # credo:disable-for-this-file
      @dialyzer :no_opaque

      <%= for a <- alias_list do %>alias <%= a %>
      <% end %>

      use TypedStruct
      use Accessible

      # This line tells the Jason library how to encode the typedstruct below
      # With no arguments, this tells Jason to encode everything except the `:__struct__` field
      # See https://hexdocs.pm/jason/Jason.Encoder.html
      @derive Jason.Encoder

      typedstruct do
      <%= for field <- fields do %><%= typedstruct_field(field) %>
      <% end %>
      end

      @behaviour Avro.AvroModule

      @impl true
      def avro_fqn(), do: "<%= avro_fqn %>"

      @impl true
      def avro_schema_name(), do: "<%= derive_namespace_from_fqn(avro_fqn) %>"

      @impl true
      def to_avro_map(%__MODULE__{} = r) do
        %{
        <%= Enum.map_join(fields, ",\n", fn field -> to_avro_map_field(field, global) end)  %>
        }
      end

      @impl true
      def from_avro_map(%{
        <%= Enum.map_join(fields, ",\n", fn field -> from_avro_map_head_field(field, global) end)  %>
      }) do
        {:ok, %__MODULE__{
          <%= Enum.map_join(fields, ",\n", fn field -> from_avro_map_body_field(field, global) end)  %>
        }}
      end

      @expected_keys MapSet.new(
      [<%= Enum.map(fields, fn %{"name" => f} -> Enum.join(["\\"", f, "\\""]) end) |> Enum.join(", ") %>
      ])

      def from_avro_map(%{} = invalid) do
        actual = Map.keys(invalid) |> MapSet.new()
        missing = MapSet.difference(@expected_keys, actual) |> Enum.join(", ")
        {:error, "Missing keys: " <> missing}
      end

      def from_avro_map(_) do
        {:error, "Expected a map."}
      end

      @pii_fields MapSet.new(
      [<%= Enum.filter(fields, fn f -> Map.get(f, "pii", false) == true end) |> Enum.map(fn %{"name" => f} -> ":" <>  f end) |> Enum.join(", ") %>
      ])

      def pii_fields(), do: @pii_fields

      def drop_pii(%__MODULE__{} = r) do
        m = Map.from_struct(r)
        <%= Enum.map(fields, fn field -> drop_pii_field("m", field, global) end) |> Enum.reject(fn s -> String.length(s) == 0 end) |> Enum.join("\n") %>
        Kernel.struct(__MODULE__, m)
      end

      alias Avro.Util.Random
      alias Avro.Util.Random.Constructors

      @spec random_instance(Random.rand_state()) :: {Random.rand_state(), struct()}
      def random_instance(rand_state) do
        Constructors.instantiate(rand_state, __MODULE__, [
          <%= Enum.map_join(fields, ",\n", fn field -> field["name"] <> ": " <> random_instance_field(field, global) end)  %>
        ])
      end
    end
    """,
    [
      :module_name_prefix,
      :name,
      :alias_list,
      :fields,
      :global,
      :moduledoc,
      :avro_fqn
    ]
  )

  # <%= Enum.map_join(fields, ",\n", fn field -> drop_pii_field("m", field, global) end) %>

  def traverse(schemas, global, parent_namespace) when is_list(schemas) do
    Enum.reduce(schemas, global, fn schema, g -> traverse(schema, g, parent_namespace) end)
  end

  def traverse(
        %{"type" => "record", "name" => name, "fields" => fields} = t,
        global,
        parent_namespace
      ) do
    field_parent_namespace = get_namespace(parent_namespace, t)

    # rewrite t: externalise all inlined enum types; add respective schemas to global
    {rewritten_fields, global} = externalise_inlined_enums(fields, global, field_parent_namespace)
    rewritten_t = Map.put(t, "fields", rewritten_fields)

    # the fully qualified names of referenced schemas
    # (after externalising inlined enums)
    referenced_schemas = get_references(rewritten_t)

    global =
      Map.put(global, get_fullname(parent_namespace, t), %{
        type: :record,
        name: Macro.camelize(name),
        referenced_schemas: referenced_schemas,
        schema: rewritten_t
      })

    Enum.reduce(fields, global, fn field, g -> traverse(field, g, field_parent_namespace) end)
  end

  def traverse(%{"type" => %{"type" => _} = inlined_type} = t, global, parent_namespace) do
    parent_namespace = get_namespace(parent_namespace, t)
    traverse(inlined_type, global, parent_namespace)
  end

  def traverse(%{"type" => "enum", "name" => name} = t, global, parent_namespace) do
    Map.put(global, get_fullname(parent_namespace, t), %{
      type: :enum,
      name: Macro.camelize(name),
      schema: t
    })
  end

  def traverse(%{"type" => "array", "items" => it} = t, global, parent_namespace) do
    parent_namespace = get_namespace(parent_namespace, t)
    traverse(it, global, parent_namespace)
  end

  def traverse(%{"type" => union} = t, global, parent_namespace) when is_list(union) do
    parent_namespace = get_namespace(parent_namespace, t)
    Enum.reduce(union, global, fn u, g -> traverse(u, g, parent_namespace) end)
  end

  def traverse(%{"type" => primitive_or_reference}, global, _parent_namespace)
      when is_binary(primitive_or_reference) do
    global
  end

  def traverse(primitive_or_reference, global, _parent_namespace)
      when is_binary(primitive_or_reference) do
    global
  end

  def traverse(other, _, _) do
    raise "cannot traverse #{inspect(other)}"
  end

  # given a possibly nil parent namespace and a type, work out the closest
  # enclosing namespace for the type
  def get_namespace(nil, %{"namespace" => namespace}), do: namespace
  def get_namespace(parent_namespace, _), do: parent_namespace

  # work out full name for complex types
  def get_fullname(_parent_namespace, %{"namespace" => namespace, "name" => name})
      when not is_nil(namespace),
      do: "#{namespace}.#{name}"

  def get_fullname(nil, %{"name" => name}), do: "#{name}"

  def get_fullname(parent_namespace, %{"name" => name}),
    do: "#{parent_namespace}.#{Macro.camelize(name)}"

  # pull out all inlined enum definitions and rewrite schema
  def externalise_inlined_enums(
        fields,
        global,
        parent_namespace
      )
      when is_list(fields) do
    {rewritten_fields, updated_global} =
      Enum.reduce(fields, {[], global}, fn field, {acc, g} ->
        {updated_field, updated_g} = maybe_externalise_enum(field, g, parent_namespace)
        {[updated_field | acc], updated_g}
      end)

    {Enum.reverse(rewritten_fields), updated_global}
  end

  def maybe_externalise_enum(
        %{"type" => %{"type" => "enum", "name" => name} = inlined_enum} = field,
        global,
        parent_namespace
      ) do
    fqn = get_fullname(parent_namespace, inlined_enum)
    rewritten_field = Map.put(field, "type", fqn)

    updated_global =
      Map.put(global, fqn, %{
        type: :enum,
        name: Macro.camelize(name),
        schema: inlined_enum
      })

    {rewritten_field, updated_global}
  end

  def maybe_externalise_enum(
        %{"type" => union} = field,
        global,
        parent_namespace
      )
      when is_list(union) do
    {updated_union, updated_global} =
      Enum.reduce(union, {[], global}, fn t, {acc, g} ->
        {updated_type, updated_g} = maybe_externalise_enum(t, g, parent_namespace)
        {[updated_type | acc], updated_g}
      end)

    {Map.put(field, "type", Enum.reverse(updated_union)), updated_global}
  end

  def maybe_externalise_enum(
        %{"type" => "enum", "name" => name} = inlined_enum,
        global,
        parent_namespace
      ) do
    fqn = get_fullname(parent_namespace, inlined_enum)

    updated_global =
      Map.put(global, fqn, %{
        type: :enum,
        name: Macro.camelize(name),
        schema: inlined_enum
      })

    {fqn, updated_global}
  end

  def maybe_externalise_enum(field, global, _parent_namespace) do
    {field, global}
  end

  # find all fqn references hidden in a record's fields
  def get_references(%{"type" => "record", "fields" => fields}) do
    fields
    |> Enum.flat_map(&refs/1)
    |> MapSet.new()
    |> Enum.sort()
  end

  defp refs(t) when is_binary(t) do
    if is_primitive(t) do
      []
    else
      [t]
    end
  end

  defp refs(ts) when is_list(ts), do: Enum.flat_map(ts, &refs/1)

  defp refs(%{"type" => "array", "items" => it}), do: refs(it)

  defp refs(%{"type" => t}), do: refs(t)

  def ensure_capitalized(s) when is_binary(s) do
    first = String.at(s, 0)

    if String.upcase(first) == first do
      s
    else
      String.capitalize(s)
    end
  end

  defp record_union?(union, global) do
    Enum.all?(union, fn u -> not is_primitive(u) end) and
      not Enum.any?(union, fn
        %{"logicalType" => _} -> true
        _ -> false
      end) and
      not Enum.any?(union, fn u ->
        case Map.get(global, u, nil) do
          nil -> true
          %{type: x} -> x != :record
        end
      end)
  end

  def drop_pii_field(var, %{"pii" => true, "name" => name, "type" => ["null" | _]}, _global) do
    "#{var} = Map.replace(m, :#{name}, nil)"
  end

  def drop_pii_field(var, %{"name" => name, "type" => ["null" | union]}, global) do
    if record_union?(union, global) do
      "#{var}_field = case Map.get(#{var}, :#{name}) do \n" <>
        Enum.map_join(union, "\n", fn u ->
          # making an assumption here; can make more sophisticated if/when
          # necessary in the future
          %{type: :record, name: module} = Map.get(global, u)
          "%#{module}{} = f -> #{module}.drop_pii(f)"
        end) <>
        "\nother -> other" <>
        "\nend\n" <>
        "#{var} = Map.replace(m, :#{name}, #{var}_field)"
    else
      ""
    end
  end

  def drop_pii_field(
        var,
        %{"pii" => true, "name" => name, "type" => %{"type" => "array"}},
        _global
      ) do
    "#{var} = Map.replace(m, :#{name}, [])"
  end

  def drop_pii_field(var, %{"name" => name, "type" => %{"type" => "array", "items" => t}}, global) do
    case Map.get(global, t) do
      %{type: :record, name: module} ->
        "#{var} = Map.replace(#{var}, :#{name}, Map.get(#{var}, :#{name}, []) |> Enum.map(&#{module}.drop_pii/1) )"

      _ ->
        ""
    end
  end

  def drop_pii_field(var, %{"pii" => true, "name" => name, "type" => t}, _global) do
    if is_primitive(t) do
      "#{var} = Map.replace(m, :#{name}, #{primitive_zero_val(t)})"
    else
      raise "# TODO handle drop PII :#{name} #{inspect(t)}"
    end
  end

  def drop_pii_field(var, %{"name" => name, "type" => t}, global) do
    case Map.get(global, t) do
      %{type: :record, name: module} ->
        "#{var} = Map.replace(#{var}, :#{name}, #{module}.drop_pii( Map.get(#{var}, :#{name}) ))"

      _ ->
        ""
    end
  end

  def drop_pii_field(_, _, _), do: ""

  def from_avro_map_head_field(%{"name" => name}, _global) do
    ~s'"#{name}" => #{name}'
  end

  def random_instance_logical_type_constructor(lt, range_opts \\ "") do
    case lt do
      "big_decimal" -> "Avro.Util.Random.Constructors.decimal(#{range_opts})"
      "iso_date" -> "Avro.Util.Random.Constructors.date(#{range_opts})"
      "iso_datetime" -> "Avro.Util.Random.Constructors.datetime(#{range_opts})"
    end
  end

  def random_instance_primitive_constructor(p, range_opts \\ "") do
    case p do
      "null" -> "Avro.Util.Random.Constructors.nothing()"
      "boolean" -> "Avro.Util.Random.Constructors.boolean()"
      "int" -> "Avro.Util.Random.Constructors.integer(#{range_opts})"
      "long" -> "Avro.Util.Random.Constructors.integer(#{range_opts})"
      "float" -> "Avro.Util.Random.Constructors.float(#{range_opts})"
      "double" -> "Avro.Util.Random.Constructors.float(#{range_opts})"
      "bytes" -> "Avro.Util.Random.Constructors.string(#{range_opts})"
      "string" -> "Avro.Util.Random.Constructors.string(#{range_opts})"
    end
  end

  # analogous to from_avro_map_body_field
  def random_instance_field(%{"logicalType" => lt} = field, _global) do
    random_instance_logical_type_constructor(lt, range_opts(field, lt))
  end

  def random_instance_field(%{"type" => %{"logicalType" => lt}} = field, _global) do
    random_instance_logical_type_constructor(lt, range_opts(field, lt))
  end

  def random_instance_field(%{"type" => union}, global) when is_list(union) do
    primitive =
      union
      |> Enum.filter(fn p -> is_binary(p) and is_primitive(p) end)
      |> Enum.map(fn p -> random_instance_primitive_constructor(p) end)

    logical =
      union
      |> Enum.filter(fn
        %{"logicalType" => _lt} -> true
        _ -> false
      end)
      |> Enum.map(fn %{"logicalType" => lt} -> random_instance_logical_type_constructor(lt) end)

    # TODO!
    arrays =
      union
      |> Enum.filter(fn
        %{"type" => "array"} -> true
        _ -> false
      end)
      |> Enum.map(fn %{"items" => t} -> global[t] end)
      |> Enum.reject(fn t -> is_nil(t) end)
      |> Enum.map(fn
        %{name: n, type: :record} ->
          ~s'Avro.Util.Random.Constructors.list(fn rand_state -> #{n}.random_instance(rand_state) end)'

        %{name: n, type: :enum} ->
          ~s'Avro.Util.Random.Constructors.list(Avro.Util.Random.Constructors.enum_value(#{n}))'
      end)

    complex =
      union
      # filter out primitives -- dealt with separately (see above)
      # we deal with logical types separately (see above)
      # we deal with arrays separately (see above)
      |> Enum.reject(fn
        t when is_binary(t) -> is_primitive(t)
        %{"logicalType" => _} -> true
        %{"type" => "array"} -> true
        _ -> false
      end)
      |> Enum.map(fn t ->
        case global[t] do
          %{type: :enum} ->
            ~s'Avro.Util.Random.Constructors.enum_value(#{Map.get(global[t], :name)})'

          %{type: :record, name: _record_name} ->
            ~s'fn rand_state -> #{Map.get(global[t], :name)}.random_instance(rand_state) end'
        end
      end)

    # special = logical ++ arrays ++ complex
    constructors = primitive ++ logical ++ arrays ++ complex

    "[" <> Enum.join(constructors, ", ") <> "]"
  end

  def random_instance_field(
        %{"type" => %{"type" => "array", "items" => type}},
        global
      ) do
    if is_primitive(type) do
      ~s"Avro.Util.Random.Constructors.list(#{random_instance_primitive_constructor(type)})"
    else
      case Map.get(global[type], :type) do
        :record ->
          ~s'Avro.Util.Random.Constructors.list(fn rand_state -> #{Map.get(global[type], :name)}.random_instance(rand_state) end)'

        :enum ->
          ~s'Avro.Util.Random.Constructors.list(Avro.Util.Random.Constructors.enum_value(#{Map.get(global[type], :name)}))'
      end
    end
  end

  def random_instance_field(%{"type" => type} = field, global) do
    if is_primitive(type) do
      random_instance_primitive_constructor(type, range_opts(field, type))
    else
      case Map.get(global[type], :type) do
        :record ->
          ~s'fn rand_state -> #{Map.get(global[type], :name)}.random_instance(rand_state) end'

        :enum ->
          ~s'Avro.Util.Random.Constructors.enum_value(#{Map.get(global[type], :name)})'
      end
    end
  end

  def range_opts(%{"range" => range_info}, type) do
    Map.get(range_info, type, %{})
    |> Enum.to_list()
    |> Enum.map(fn {k, v} -> {String.to_atom(k), v} end)
    |> inspect()
  end

  def range_opts(_, _), do: ""

  def from_avro_map_body_field(%{"name" => name, "logicalType" => lt}, _global) do
    ~s'#{name}: #{conversion_from_incantation(lt, name)}'
  end

  def from_avro_map_body_field(%{"name" => name, "type" => %{"logicalType" => lt}}, _global) do
    ~s'#{name}: #{conversion_from_incantation(lt, name)}'
  end

  def from_avro_map_body_field(%{"name" => name, "type" => union}, global) when is_list(union) do
    logical =
      union
      |> Enum.filter(fn
        %{"logicalType" => _lt} -> true
        _ -> false
      end)
      |> Enum.map(fn %{"logicalType" => lt} -> from_cond_conversion_incantation(lt, name) end)

    arrays =
      union
      |> Enum.filter(fn
        %{"type" => "array"} -> true
        _ -> false
      end)
      |> Enum.map(fn %{"items" => t} -> global[t] end)
      |> Enum.reject(fn t -> is_nil(t) end)
      |> Enum.map(fn
        %{name: n, type: :record} ->
          # hmmmm???
          [
            ~s"""
            is_list(#{name}) and ( #{name} |> Enum.map(fn e -> #{n}.from_avro_map(e) end) |> Noether.List.sequence() |> elem(0) == :ok )
            """
            |> String.trim(),
            ~s"""
            #{name} |> Enum.map(fn e -> #{n}.from_avro_map(e) end) |> Noether.List.sequence() |> Noether.Either.map_error(fn _ -> raise "error when invoking from_avro_map on array of #{n}" end) |> Noether.Either.unwrap()
            """
          ]

        %{name: n, type: :enum} ->
          [
            ~s"""
            is_list(#{name}) and ( #{name} |> Enum.map(fn e -> #{n}.value(e) end) |> Noether.List.sequence() |> elem(0) == :ok )
            """
            |> String.trim(),
            ~s"""
            #{name} |> Enum.map(fn v -> #{n}.value(v) end) |> Noether.List.sequence() |> Noether.Either.map_error(fn msg -> raise msg end) |> Noether.Either.unwrap()
            """
          ]
      end)

    complex =
      union
      # filter out primitives
      # we deal with logical types separately (see above)
      # we deal with arrays separately (see above)
      |> Enum.reject(fn
        t when is_binary(t) -> is_primitive(t)
        %{"logicalType" => _} -> true
        %{"type" => "array"} -> true
        _ -> false
      end)
      |> Enum.map(fn t ->
        case global[t] do
          %{type: :enum} ->
            [
              ~s'#{Map.get(global[t], :name)}.value(#{name}) |> Noether.Either.ok?',
              ~s'#{Map.get(global[t], :name)}.value(#{name}) |> Noether.Either.unwrap()'
            ]

          %{type: :record, name: _record_name} ->
            # [
            # ~s'not is_nil(#{name}) and ( #{Map.get(global[t], :name)}.from_avro_map(#{name}) |> elem(0) == :ok )',
            # ~s'#{Map.get(global[t], :name)}.from_avro_map(#{name}) |> elem(1)'
            # ]
            [
              ~s'#{name} |> #{Map.get(global[t], :name)}.from_avro_map() |> Noether.Either.ok?()',
              ~s'#{name} |> #{Map.get(global[t], :name)}.from_avro_map() |> Noether.Either.unwrap()'
            ]
        end
      end)

    special = logical ++ arrays ++ complex

    case special do
      [] ->
        ~s'#{name}: #{name}'

      [[condition, action]] ->
        ~s"""
        #{name}: if #{condition} do
          #{action}
        else
          #{name}
        end
        """
        |> String.trim()

      _ ->
        clauses =
          special
          |> Enum.map_join("\n", fn ca -> Enum.join(ca, " -> ") end)

        ~s"""
        #{name}: cond do
          #{clauses}
          true -> #{name}
        end
        """
        |> String.trim()
    end
  end

  def from_avro_map_body_field(
        %{"name" => name, "type" => %{"type" => "array", "items" => type}},
        global
      ) do
    if is_primitive(type) do
      ~s'#{name}: #{name}'
    else
      case Map.get(global[type], :type) do
        :record ->
          # if type is a record, we need to call the respective fromavromap
          # function on its module for every array element -- which returns an ok/error tuple
          ~s"""
          #{name}: Enum.map(#{name}, fn e -> #{Map.get(global[type], :name)}.from_avro_map(e) end)
            |> Noether.List.sequence()
            |> Noether.Either.map_error(fn _ -> raise "#{Map.get(global[type], :name)}.from_avro_map() failed on field #{name}" end)
            |> Noether.Either.unwrap()
          """
          |> String.trim()

        :enum ->
          # if type is an enum, we need to from_string it for every array element
          ~s"""
          #{name}: Enum.map(#{name}, fn v -> #{Map.get(global[type], :name)}.value(v) end)
          |> Noether.List.sequence()
          |> Noether.Either.map_error(fn msg -> raise msg end)
          |> Noether.Either.unwrap()
          """
          |> String.trim()
      end
    end
  end

  def from_avro_map_body_field(%{"name" => name, "type" => type}, global) do
    if is_primitive(type) do
      ~s'#{name}: #{name}'
    else
      case Map.get(global[type], :type) do
        :record ->
          # if type is a record, we need to call the respective fromavromap
          # function on its module -- which returns an ok/error tuple
          ~s'#{name}: #{Map.get(global[type], :name)}.from_avro_map(#{name}) |> Noether.Either.map_error(fn e -> raise "#{Map.get(global[type], :name)}.from_avro_map(#{name}) failed: #\#{if is_binary(e), do: e, else: inspect(e)}" end) |> Noether.Either.unwrap()'

        :enum ->
          # if type is an enum, we need to from_string it
          ~s"""
          #{name}: #{Map.get(global[type], :name)}.value(#{name})
          |> Noether.Either.map_error(fn msg -> raise msg end)
          |> Noether.Either.unwrap()
          """
          |> String.trim()
      end
    end
  end

  def from_cond_conversion_incantation("big_decimal", inner),
    do: [
      "not is_nil(#{inner}) and (Decimal.parse(#{inner}) != :error)",
      "Decimal.new(#{inner})"
    ]

  def from_cond_conversion_incantation("iso_date", inner),
    do: [
      "is_binary(#{inner}) and ( Date.from_iso8601(#{inner}) |> elem(0) == :ok)",
      "Date.from_iso8601(#{inner}) |> elem(1)"
    ]

  # TODO: what about the offset??
  def from_cond_conversion_incantation("iso_datetime", inner),
    do: [
      "is_binary(#{inner}) and ( DateTime.from_iso8601(#{inner} |> elem(0) == :ok)",
      "DateTime.from_iso8601(#{inner}) |> elem(1)"
    ]

  def conversion_from_incantation("big_decimal", inner), do: ~s'Decimal.new(#{inner})'

  def conversion_from_incantation("iso_date", inner) do
    ~s'Date.from_iso8601!(#{inner})'
  end

  def conversion_from_incantation("iso_datetime", inner) do
    ~s'DateTime.from_iso8601(#{inner}) |> elem(1)'
  end

  def to_avro_map_field(%{"name" => name, "logicalType" => logical_type}, _global) do
    ~s'"#{name}" => #{conversion_incantation(logical_type, "r.#{name}")}'
  end

  def to_avro_map_field(%{"name" => name, "type" => type}, global) when is_binary(type) do
    if is_primitive(type) do
      ~s'"#{name}" => r.#{name}'
    else
      case Map.get(global[type], :type) do
        :record ->
          # if type is a record, we need to call the respective toavromap function on its module
          ~s'"#{name}" => #{Map.get(global[type], :name)}.to_avro_map(r.#{name})'

        :enum ->
          # if type is an enum, we need to to_string it
          ~s'"#{name}" => Atom.to_string(r.#{name})'
      end
    end
  end

  def to_avro_map_field(%{"name" => name, "type" => union}, global) when is_list(union) do
    logical =
      union
      |> Enum.filter(fn
        %{"logicalType" => _lt} -> true
        _ -> false
      end)
      |> Enum.map(fn %{"logicalType" => lt} -> match_conversion_incantation(lt) end)

    arrays =
      union
      |> Enum.filter(fn
        %{"type" => "array"} -> true
        _ -> false
      end)
      |> Enum.map(fn %{"items" => t} -> global[t] end)
      |> Enum.reject(fn t -> is_nil(t) end)
      |> Enum.map(fn
        %{name: n, type: :record} ->
          ~s'elements when is_list(elements) -> Enum.map(r.#{name}, fn v -> #{n}.to_avro_map(v) end)'

        %{type: :enum} ->
          ~s'elements when is_list(elements) -> Enum.map(r.#{name}, fn v -> Atom.to_string(v) end)'
      end)

    complex =
      union
      # filter out primitives
      # we deal with logical types separately (see above)
      # we deal with arrays separately (see above)
      |> Enum.reject(fn
        t when is_binary(t) -> is_primitive(t)
        %{"logicalType" => _} -> true
        %{"type" => "array"} -> true
        _ -> false
      end)
      |> Enum.map(fn t ->
        case global[t] do
          %{type: :enum} ->
            ~s'enum_value when is_atom(enum_value) and not is_nil(enum_value) -> Atom.to_string(enum_value)'

          %{type: :record, name: record_name} ->
            ~s'%#{record_name}{} = record -> #{record_name}.to_avro_map(record)'
        end
      end)

    special = logical ++ arrays ++ complex

    if special == [] do
      ~s'"#{name}" => r.#{name}'
    else
      ~s"""
      "#{name}" => case r.#{name} do
       #{Enum.join(special, "\n")}
      _ -> r.#{name}
      end
      """
      |> String.trim()
    end
  end

  # TODO: logical types in arrays
  def to_avro_map_field(
        %{"name" => _name, "type" => %{"type" => "array", "items" => %{"logicalType" => lt}}},
        _global
      ) do
    raise "not yet supporting logical types in arrays (#{lt})"
  end

  def to_avro_map_field(
        %{"name" => name, "type" => %{"type" => "array", "items" => type}},
        global
      )
      when is_binary(type) do
    if is_primitive(type) do
      ~s'"#{name}" => r.#{name}'
    else
      case Map.get(global[type], :type) do
        :record ->
          ~s'"#{name}" => Enum.map(r.#{name}, fn v -> #{Map.get(global[type], :name)}.to_avro_map(v) end)'

        :enum ->
          ~s'"#{name}" => Enum.map(r.#{name}, fn v -> Atom.to_string(v) end)'
      end
    end
  end

  def to_avro_map_field(%{"name" => name, "type" => %{"logicalType" => logical_type}}, _global) do
    ~s'"#{name}" => #{conversion_incantation(logical_type, "r.#{name}")}'
  end

  def match_conversion_incantation("iso_date") do
    ~s'%Date{} = d -> Date.to_iso8601(d)'
  end

  def match_conversion_incantation("iso_datetime") do
    ~s'%DateTime{} = d -> DateTime.to_iso8601(d)'
  end

  def match_conversion_incantation("big_decimal") do
    ~s'%Decimal{} = d -> Decimal.to_string(d)'
  end

  def conversion_incantation("iso_date", inner) do
    ~s'Date.to_iso8601(#{inner})'
  end

  def conversion_incantation("iso_datetime", inner) do
    ~s'DateTime.to_iso8601(#{inner})'
  end

  def conversion_incantation("big_decimal", inner) do
    ~s'Decimal.to_string(#{inner})'
  end

  def field_comment(%{"name" => name, "doc" => doc}, indent) do
    str = String.trim("`#{name}`: #{doc}") <> "\n"
    buff = String.duplicate(" ", indent)
    Enum.join(String.split(str, "\n"), "\n" <> buff)
  end

  def field_comment(%{"name" => name}, _indent) do
    Excribe.format(String.trim("`#{name}`: #{name}") <> "\n")
  end

  def field_comment(_, _), do: ""

  def indent(str, indent) when is_binary(str) do
    buff = String.duplicate(" ", indent)
    buff <> Enum.join(String.split(str, "\n"), "\n" <> buff)
  end

  def indent(_, _) do
    ""
  end

  EEx.function_from_string(
    :def,
    :typedstruct_field,
    ~s'field :<%= field["name"] %>, <%= typedstruct_field_type(field) %><%= if enforce(field["type"]) do %>, enforce: true<% end %>',
    [:field]
  )

  def typedstruct_field_type(%{"type" => union}) when is_list(union) do
    union
    |> Enum.map_join(" | ", &elixir_type/1)
  end

  def typedstruct_field_type(%{"logicalType" => t}), do: elixir_type_for_logical_type(t)
  def typedstruct_field_type(%{"type" => single}) when is_binary(single), do: elixir_type(single)
  def typedstruct_field_type(%{"type" => %{"type" => "array"} = array}), do: elixir_type(array)

  def typedstruct_field_type(%{"type" => %{"logicalType" => t}}),
    do: elixir_type_for_logical_type(t)

  def elixir_type("null"), do: "nil"
  def elixir_type("string"), do: "String.t()"
  def elixir_type("int"), do: "integer()"
  def elixir_type("boolean"), do: "boolean()"
  def elixir_type("double"), do: "float()"

  def elixir_type(%{"logicalType" => t}), do: elixir_type_for_logical_type(t)

  def elixir_type(%{"type" => "enum", "name" => n}) do
    String.capitalize(n) <> ".t()"
  end

  def elixir_type(%{"type" => "array", "items" => n}) do
    "[" <> elixir_type(n) <> "]"
  end

  def elixir_type(%{"type" => t}), do: elixir_type(t)

  def elixir_type(s) do
    case String.split(s, ".") do
      [_, _ | _] = l -> List.last(l) <> ".t()"
      [other] -> raise("Generator does not (yet?) support #{inspect(other)}.")
    end
  end

  @logical_types %{
    "iso_date" => "Date.t()",
    "iso_datetime" => "DateTime.t()",
    "big_decimal" => "Decimal.t()"
  }
  def elixir_type_for_logical_type(t) do
    case Map.get(@logical_types, t) do
      nil -> raise "Logical type #{t} not (yet?) supported."
      elixir_type -> elixir_type
    end
  end

  @primitives ["null", "boolean", "int", "long", "float", "double", "bytes", "string"]
  def is_primitive(s), do: s in @primitives
  # ^^^ add ? to function name

  def primitive_zero_val("string"), do: ~s{""}
  def primitive_zero_val("int"), do: 0
  def primitive_zero_val("float"), do: 0.0
  def primitive_zero_val("double"), do: 0.0
  def primitive_zero_val(other), do: raise("not yet handled: #{inspect(other)}")

  def last_component(s) do
    s
    |> String.split(".")
    |> List.last()
  end

  # %{logical_type}
  # complex type

  # we want to set `enforce: true` for a typedstruct field unless it's optional, i.e.
  # is part of a union that has the "null" type in it
  def enforce(union) when is_list(union) do
    not Enum.member?(union, "null")
  end

  def enforce(_), do: true
end
