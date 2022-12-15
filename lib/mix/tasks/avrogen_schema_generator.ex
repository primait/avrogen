defmodule Mix.Tasks.Compile.AvroSchemaGenerator do
  @moduledoc """
  Compiler task to generate avro schemas from templates defined in elixir.

  ## Usage

  Use this task by adding it to the list of compilers in your mix.exs for your project, and add
  configuration options using the `avro_schema_generator_opts` key in your project options.

  Example configuration:
  ```
  def project do
    [
      ...
      compilers: [:avro_schema_generator | Mix.compilers()],
      ...
      avro_schema_generator_opts: [
        paths: ["schema/**/*.exs"],
        dest: "priv/schema/"
      ]
      ...
    ]
  end
  ```

  Where:

  - paths: A list of wildcards used to locate elixir template files to generate code for. Each path
      is evaluated with Path.wildcard().
  - dest: Where to put the generated schema files.

  ## Schema File Naming

  Schema files are generated one schema per file, where the name of each file is described below.

  ```
  <schema_root>/<schemanamespace>.<SchemaName>.avsc
  ```

  E.g. `root/foo.bar/Baz.avsc`

  ## Dependency Tracking

  In order to make the build as fast as possible, it is important that this task only generates
  files when it needs to, i.e. when sources have changed thus, proper dependency management is
  required.

  Each template file (exs) will generate one or more schema file (avsc), one for each schema it
  defines. Thus each generated schema file will depend only on its source exs file.

  Example dependency tree:

  foo.exs <─┬─ foo.Bar.avsc
            ├─ foo.Baz.avsc
            └─ foo.Qux.avsc

  Arrows point in the direction of the dependency, e.g. foo.Bar.avsc depends on foo.exs. This means
  that the content of foo.Bar.avsc depends entirely on the content of foo.exs, so it must be updated
  only if foo.exs is newer than it.

  Because it's not obvious what ex files would be generated (without just running the generation),
  each time we run the task we store the list of generated files in a manifest file. The next time
  we run the task, the list of  generated files from the previous run is recalled by reading the
  manifest file, and this list is used to work out if any of the generated files are older than any
  of their dependencies, thus triggering a re-gen of just those files.

  This manifest could also used to know which files to delete when running a clean operation, but
  unfortunately running mix clean when this app is in an umbrella doesn't work. I think this is
  because this task is "cleaned" before it has a chance to run, which effectively wipes out this
  task entirely. If we made this app an external dependency, it wouldn't be cleaned with mix clean
  and thus will work just fine.
  """

  use Mix.Task.Compiler
  import HappyWith

  # Note: This makes tasks run in the correct context when using an umbrella
  @recursive true

  @manifest "generate.avro.schema.manifest"
  @manifest_version 1

  defmodule TaskSummary do
    @moduledoc """
    Defines a list of sources (i.e. input files) and targets (i.e. output files) for a given task.
    """
    import TypedStruct

    typedstruct do
      field(:sources, [String.t()], default: [])
      field(:targets, [String.t()], default: [])
    end
  end

  defmodule Manifest do
    @moduledoc """
    Defines lists of tasks by the filenames of their outputs, and their dependencies (i.e. inputs).
    In this case, all tasks have one input (the exs schema template file) and one or more outputs
    (each of the generated avsc files).
    We also store the task's options, to detect config changes which might affect the output files.
    """
    import TypedStruct

    typedstruct do
      field(:options, Keyword.t(), default: [])
      field(:tasks, [TaskSummary.t()], default: [])
    end
  end

  @impl true
  @shortdoc "Generates avro schemas from exs template files"
  def run(_args) do
    Application.ensure_loaded(Application.get_application(__MODULE__))

    manifest_path()
    |> load_manifest()
    |> generate!()
  end

  defp generate!(%Manifest{
         options: previous_options,
         tasks: cache
       }) do
    options = opts()

    force = config_changed?(previous_options, options)

    paths = Keyword.get(options, :paths, ["exs_schemas/**/*.exs"])
    dest = Keyword.get(options, :dest, "schemas")
    schema_resolution_mode = Keyword.get(options, :schema_resolution_mode, :flat)

    {tasks, status} =
      paths
      |> Enum.flat_map(&Path.wildcard/1)
      |> Enum.map(&check_schema_file_state(&1, cache, force))
      |> tap(&report/1)
      |> Enum.map(&run_task!(&1, dest, schema_resolution_mode))
      |> tap(&cleanup_dest!(&1, dest))
      |> Enum.map_reduce(:noop, fn
        {:ok, task}, _status -> {task, :ok}
        {:noop, task}, status -> {task, status}
      end)

    manifest = %Manifest{options: options, tasks: tasks}
    timestamp = System.os_time(:second)
    write_manifest(manifest, timestamp)

    status
  end

  defp check_schema_file_state(path_to_template_file, cache, force) do
    Enum.find(cache, fn %TaskSummary{sources: sources} -> sources == [path_to_template_file] end)
    |> case do
      nil ->
        {:stale, path_to_template_file, []}

      %TaskSummary{sources: sources, targets: targets} ->
        (Mix.Utils.stale?(sources, targets) || force)
        |> case do
          true -> {:stale, path_to_template_file, targets}
          false -> {:noop, path_to_template_file, targets}
        end
    end
  end

  defp report(files) do
    Enum.count(files, fn
      {:stale, _, _} -> true
      {:noop, _, _} -> false
    end)
    |> case do
      0 -> nil
      count -> log("Processing #{count} avro schema template file(s)")
    end
  end

  defp run_task!({:stale, file, _outputs}, dest, schema_resolution_mode) do
    {
      :ok,
      %TaskSummary{
        sources: [file],
        targets: Avrogen.SchemaGenerator.generate_avsc_files!(file, dest, schema_resolution_mode)
      }
    }
  end

  defp run_task!({_state, file, outputs}, _dest, _schema_resolution_mode) do
    {:noop, %TaskSummary{sources: [file], targets: outputs}}
  end

  defp cleanup_dest!(tasks, dest_dir) do
    generated_files = Enum.flat_map(tasks, fn {_, %TaskSummary{targets: targets}} -> targets end)

    ls_r(dest_dir)
    |> Enum.each(fn file ->
      if !Enum.member?(generated_files, file) do
        log("Removing rogue file #{file}")
        File.rm!(file)
      end
    end)
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

  defp config_changed?(config_old, config) do
    Enum.sort(config_old) != Enum.sort(config)
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
         tasks: tasks
       }) do
    tasks
    |> Enum.flat_map(fn %TaskSummary{targets: targets} -> targets end)
    |> List.insert_at(0, manifest_path())
    |> Enum.each(fn target ->
      File.rm(target)
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
    case Keyword.get(Mix.Project.config(), :avro_schema_generator_opts, nil) do
      nil -> Keyword.new()
      opts -> opts
    end
  end

  defp log(message) do
    print_app_name()
    IO.puts(message)
  end
end
