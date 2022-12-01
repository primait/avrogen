defmodule Avrogen.Schema do
  @moduledoc """
  Utils for extracting various info from avro schemas.
  Schemas can be records or enums.
  """

  @type schema() :: map()

  @doc """
  Get a list of external types referenced in a given record/enum.
  """
  @spec external_dependencies(schema()) :: [String.t()]
  def external_dependencies(%{"type" => "record", "fields" => fields}) do
    fields
    |> Enum.flat_map(fn
      %{"type" => types} when is_list(types) ->
        Enum.flat_map(types, fn type -> Avrogen.Types.external_dependencies(type) end)

      %{"type" => type} ->
        Avrogen.Types.external_dependencies(type)
    end)
  end

  def external_dependencies(_) do
    []
  end

  @doc """
  Get a schema's fully qualified name by combining its namespace and name.
  """
  @spec fqn(schema()) :: String.t()
  def fqn(%{"name" => name, "namespace" => namespace}) do
    "#{namespace}.#{name}"
  end

  def fqn(%{"name" => name}) do
    name
  end

  @doc """
  Get a schema's namespace.
  """
  @spec namespace(schema()) :: String.t()
  def namespace(%{"namespace" => namespace}) do
    namespace

    # Note: Unsure what to do if the schema has no namespace - make it a MatchError for now...
  end

  @doc """
  Get a schema's name.
  """
  @spec name(schema()) :: String.t()
  def name(%{"name" => name}) do
    name
  end

  @doc """
  Sort a list of avro schemas in topological order based on dependencies.
  """
  @spec fqn([schema()]) :: [schema()]
  def topological_sort(elements) do
    dependencies =
      elements
      |> Enum.map(fn element ->
        {
          fqn(element),
          element,
          external_dependencies(element)
        }
      end)

    verts = Enum.map(dependencies, fn {name, _, _} -> name end)

    edges =
      Enum.flat_map(dependencies, fn {name, _, deps} ->
        Enum.map(deps, fn dep -> {dep, name} end)
      end)

    Graph.new()
    |> Graph.add_vertices(verts)
    |> Graph.add_edges(edges)
    |> Graph.topsort()
    |> case do
      false -> {:error, :cyclic_dependencies}
      sorted -> {:ok, sorted}
    end
    |> Noether.Either.map(fn sorted ->
      sorted
      |> Enum.map(fn name ->
        {_, item, _} = List.keyfind!(dependencies, name, 0)
        item
      end)
    end)
  end

  @doc """
  Load a schema from a file.
  """
  @spec load_schema!(Path.t()) :: schema()
  def load_schema!(path_to_schema) do
    path_to_schema
    |> File.read!()
    |> Jason.decode!()
  end

  @doc """
  Derive a schema's file path from its fqn.
  """
  @spec path_from_fqn(Path.t(), String.t()) :: Path.t()
  def path_from_fqn(root, schema_fqn) do
    Path.join(root, schema_fqn) <> ".avsc"
  end

  @doc """
  Combine a set of schema files into one topologically sorted schema in json format.
  """
  @spec generate_combined_schema!([Path.t()]) :: String.t()
  def generate_combined_schema!(schema_file_paths) do
    for file_path <- schema_file_paths do
      load_schema!(file_path)
    end
    |> Avrogen.Schema.topological_sort()
    |> Jason.encode!(pretty: true)
  end
end
