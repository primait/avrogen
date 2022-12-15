defmodule Mix.Tasks.Compile.AvroCodeGenerator do
  @moduledoc """
  Compiler task to generate elixir code from avro schemas.

  ## Usage

  Use this task by adding it to the list of compilers in your mix.exs for your project, and add
  configuration options using the `avro_code_generator_opts` key in your project options.

  Example configuration:
  ```
  def project do
    [
      ...
      compilers: [:avro_code_generator | Mix.compilers()],
      ...
      avro_code_generator_opts: [
        paths: ["priv/schema/*.avsc"],
        dest: "generated/",
        schema_root: "priv/schema",
        module_prefix: "Avro.Generated"
      ]
      ...
    ]
  end
  ```

  Where:

  - paths: A list of wildcards used to locate schema files to generate code for. Each path is
      evaluated with Path.wildcard().
  - dest: Where to put the generated elixir files.
  - schema_root: Where to find external schema files (see notes on schema file naming below)
  - module_prefix: A common prefix prepended to the front of all module names.

  ## Schema File Naming

  This task requires schema files to contain one schema only (nested schemas are allowed). Where
  references are made to external schemas, it must be able to be found by looking for the schema by
  name in the directory supplied by the `schema_root` option, and the name of the schema files must
  follow the specific pattern:

  ```
  <schema_root>/<schemanamespace>.<SchemaName>.avsc
  ```

  E.g. `root/foo.bar/Baz.avsc`

  ## Generated file naming

  Generated files are named like so:

  ```
  <dest>/<namespace>/<SchemaName>.ex
  ```

  E.g. `dest/foo/bar/baz.ex

  Note, the namespace is split on periods into directories, and the schema name is converted from
  camel case into snake case.

  ## Dependency Tracking

  In order to make the build as fast as possible, this task only generates files when it needs to,
  i.e. when the schemas have changed, or when the code of the avro_compiler app has changed.

  Each avsc file will generate one or more elixir source code file, but the content of the generated
  code may depend on other avsc files if the schema references external schemas from other files.

  For example, the dependency tree of the generated file foo/Bar.ex might look like this:

  foo.Bar.avsc <─┬── foo/Bar.ex
  foo.Baz.avsc <─┤
  foo.Qux.avsc <─┘

  Arrows point in the direction of the dependency, e.g. foo/Bar.ex depends on foo.Bar.avsc,
  foo.Baz.avsc, and foo.Qux.avsc. This means that the content of foo/Bar.ex depends on the content
  all three avsc files, so it must be re-generated if any of the avsc files are modified.

  ## Cleaning the Destination Directory

  In order to keep a clean dest directory, each time the task is run, the dest dir (supplied in
  the options) is wiped clean. The generated files are generated into a directory somewhere inside
  the _build directory, and then the relevant files are copied over to the dest dir. This ensures
  no files are left behind in the dest dir which could be picked up by the elixir compiler. Thus,
  it's important that this dest dir does not contain other important files as these will be wiped
  out.

  ## Manifest File

  This task writes a manifest file containing a the config options and a list of generated files
  each time it's run. The task then uses this manifest file to work out when the options have
  changed so it can trigger a full re-build.

  This manifest could also used to know which files to delete when running a clean operation, but
  unfortunately running mix clean when this app is in an umbrella doesn't work. This is because the
  code for this task is removed before the clean operation has a chance to run, which eems like a
  major flaw in the way tasks work). Hopefully one day the Mix devs will fix this, or we could move
  this app into a separate repo and make it an external dependency of stonehenge at which point the
  clean operation would work as mix clean does not clean external deps.
  """

  use Mix.Task.Compiler
  import HappyWith
  alias Avrogen.Schema
  alias Avrogen.CodeGenerator

  # Note: This makes tasks run in the correct context when using an umbrella
  @recursive true

  @manifest "avro.code.generator.manifest"
  @manifest_version 1

  defmodule Manifest do
    import TypedStruct

    typedstruct do
      field(:options, Keyword.t(), default: [])
      field(:generated_files, [String.t()], default: [])
    end
  end

  @impl true
  @shortdoc "Generates elixir source from avsc schema files"
  def run(_args) do
    Application.ensure_loaded(Application.get_application(__MODULE__))

    manifest_path()
    |> load_manifest()
    |> generate()
  end

  defp generate(%Manifest{options: previous_options}) do
    options = opts()

    force = config_changed?(previous_options, options)

    dest = Keyword.get(options, :dest, "generated")
    paths = Keyword.get(options, :paths, ["schemas/*.avsc"])
    schema_root = Keyword.get(options, :schema_root, "schemas")
    module_prefix = Keyword.get(options, :module_prefix, "Avro")
    schema_resolution_mode = Keyword.get(options, :schema_resolution_mode, :flat)

    {generated_files, status} =
      paths
      |> Enum.flat_map(&Path.wildcard/1)
      |> Enum.map(fn path_to_schema ->
        generate_tasks(path_to_schema, schema_root, schema_resolution_mode, dest, force)
      end)
      |> tap(&report/1)
      |> Enum.map(&run_task!(&1, module_prefix))
      |> tap(&cleanup_dest!(&1, dest))
      |> Enum.map_reduce(:noop, fn
        {:ok, path_to_code}, _status -> {path_to_code, :ok}
        {:noop, path_to_code}, status -> {path_to_code, status}
      end)

    manifest = %Manifest{options: options, generated_files: generated_files}
    timestamp = System.os_time(:second)
    write_manifest(manifest, timestamp)

    status
  end

  defp config_changed?(config_old, config) do
    Enum.sort(config_old) != Enum.sort(config)
  end

  defp generate_tasks(path_to_schema, schema_root, schema_resolution_mode, dest, force) do
    schema = Schema.load_schema!(path_to_schema)

    deps =
      schema
      |> Schema.external_dependencies()
      |> Enum.map(fn schema_fqn ->
        Schema.path_from_fqn(schema_root, schema_fqn, schema_resolution_mode)
      end)

    path_to_code = CodeGenerator.filename_from_schema(dest, schema)

    status =
      case force ||
             Mix.Utils.stale?([path_to_schema | deps] ++ find_beam_files(), [
               path_to_code
             ]) do
        true -> :stale
        false -> :noop
      end

    {status, path_to_schema, deps, path_to_code}
  end

  defp report(files) do
    Enum.count(files, fn
      {:stale, _, _, _} -> true
      {:noop, _, _, _} -> false
    end)
    |> case do
      0 -> nil
      count -> log("Processing #{count} avro schema file(s)")
    end
  end

  defp run_task!({:stale, path_to_schema, deps, path_to_code}, module_prefix) do
    [schema | deps_schemas] =
      [path_to_schema | deps]
      |> Enum.map(fn schema -> File.read!(schema) |> Jason.decode!() end)

    code = CodeGenerator.generate_schema(schema, deps_schemas, module_prefix)
    File.mkdir_p!(Path.dirname(path_to_code))
    File.write!(path_to_code, code)

    {:ok, path_to_code}
  end

  defp run_task!({:noop, _, _, path_to_code}, _) do
    {:noop, path_to_code}
  end

  defp cleanup_dest!(tasks, dest_dir) do
    generated_files = for {_, path_to_code} <- tasks, do: path_to_code

    for file <- ls_r(dest_dir), not Enum.member?(generated_files, file) do
      log("Removing rogue file #{file}")
      File.rm!(file)
    end
  end

  # https://www.ryandaigle.com/a/recursively-list-files-in-elixir/
  defp ls_r(path) do
    cond do
      File.regular?(path) ->
        [path]

      File.dir?(path) ->
        File.ls!(path)
        |> Enum.map(&Path.join(path, &1))
        |> Enum.map(&ls_r/1)
        |> Enum.concat()

      true ->
        []
    end
  end

  defp find_beam_files() do
    {:ok, appname} = :application.get_application(__MODULE__)

    Mix.Project.build_path()
    |> Path.join("lib")
    |> Path.join(Atom.to_string(appname))
    |> Path.join("ebin/*")
    |> Path.wildcard()
  end

  defp print_app_name() do
    if name = Mix.Shell.printable_app_name() do
      IO.puts("==> #{name}")
    end
  end

  @doc false
  @impl true
  def manifests, do: [manifest_path()]

  @shortdoc "Delete generated artifacts"
  @impl true
  def clean() do
    manifest_path()
    |> load_manifest()
    |> do_clean()
  end

  defp do_clean(%Manifest{
         generated_files: generated_file_paths
       }) do
    generated_file_paths
    |> List.insert_at(0, manifest_path())
    |> Enum.each(fn path ->
      File.rm(path)
    end)

    # TODO: return :noop if we don't need to do anything
    :ok
  end

  defp manifest_path do
    Path.join(Mix.Project.manifest_path(), @manifest)
  end

  defp write_manifest(manifest, timestamp) do
    path = manifest_path()
    File.mkdir_p!(Path.dirname(path))

    term = {@manifest_version, manifest}
    manifest_data = :erlang.term_to_binary(term, [:compressed])
    File.write!(path, manifest_data)
    File.touch!(path, timestamp)
  end

  defp load_manifest(path) do
    happy_with do
      {:ok, content} <- File.read(path)
      data <- :erlang.binary_to_term(content)
      {@manifest_version, %Manifest{} = manifest} <- data
      manifest
    else
      _ -> %Manifest{}
    end
  end

  defp opts do
    case Keyword.get(Mix.Project.config(), :avro_code_generator_opts, nil) do
      nil -> Keyword.new()
      opts -> opts
    end
  end

  defp log(message) do
    print_app_name()
    IO.puts(message)
  end
end
