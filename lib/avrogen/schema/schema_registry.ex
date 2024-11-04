defmodule Avrogen.Schema.SchemaRegistry do
  @moduledoc """
  Stores avro schemas and corresponding codec functions; provides lookup by
  schema name. Initialized on startup with schemas from priv directory.
  """

  use GenServer
  require Logger

  @ets_name "all"

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(app) do
    table =
      :ets.new(__MODULE__, [
        :set,
        :protected,
        :named_table,
        read_concurrency: true
      ])

    config = Application.get_env(app, __MODULE__)

    exclude_files =
      config |> Keyword.get(:exclude_paths, []) |> Enum.flat_map(&app_wildcard(app, &1))

    config[:schemas_path]
    |> Enum.flat_map(fn pattern ->
      app_wildcard(app, pattern)
    end)
    |> Enum.reject(&Enum.member?(exclude_files, &1))
    |> Enum.map(fn file ->
      file
      |> File.read!()
      |> Jason.decode!()
    end)
    |> Avrogen.Schema.topological_sort()
    |> Noether.Either.map(fn schemas ->
      json = Jason.encode!(schemas)

      try do
        encoder = make_encoder(json)
        decoder = make_decoder(json)
        :ets.insert(__MODULE__, {@ets_name, json, encoder, decoder})
      rescue
        e ->
          formatted_error = Exception.format(:error, e, __STACKTRACE__)

          Logger.error(
            "Error when attempting to make encoder/decoder: #{formatted_error}; schemas: #{inspect(schemas, limit: :infinity, pretty: true, printable_limit: :infinity)} schemas_json: #{json}",
            %{
              error: formatted_error,
              schemas: schemas,
              schemas_json: json
            }
          )

          reraise e, __STACKTRACE__
      end
    end)

    {:ok, table}
  end

  @doc """
  Expand a wildcard relative to an app's root directory.
  """
  def app_wildcard(app, pattern) do
    Application.app_dir(app)
    |> Path.join(pattern)
    |> Path.wildcard()
  end

  @doc """
  Return the super-schema which contains the topologically sorted concatenation
  of all schemas managed by this registry as a json string.
  """
  def get_avsc do
    :ets.lookup_element(__MODULE__, @ets_name, 2)
  end

  @doc """
  Return the binary encoder function which is capable of encoding all messages.
  """
  def get_encoder do
    :ets.lookup_element(__MODULE__, @ets_name, 3)
  end

  @doc """
  Return the binary decoding function which is capable of decoding all schemas.
  """
  def get_decoder do
    :ets.lookup_element(__MODULE__, @ets_name, 4)
  end

  # Creates a binary format encoder function for the given avsc.
  def make_encoder(avsc) do
    :avro.make_encoder(avsc, map_type: :map, record_type: :map)
  end

  # Creates a binary format decoder function for the given avsc.
  def make_decoder(avsc) do
    :avro.make_decoder(avsc,
      map_type: :map,
      record_type: :map,
      hook: &decoder_hook/4
    )
  end

  @doc """
  A decoder hook that will convert erlavro :null values to nil.
  """
  def decoder_hook(type, _sub_name_or_id, data, decode_fun) do
    if :avro.get_type_name(type) == "null" do
      {nil, data}
    else
      decode_fun.(data)
    end
  end
end
