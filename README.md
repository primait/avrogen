# Avrogen

Generate elixir typedstructs from AVRO schemas.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `avrogen` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:avrogen, "~> 0.2.1"}
  ]
end
```

## Rationale

While there exists a handful of libraries to encode and decode AVRO messages in Elixir, all of them consume schemas at runtime, which has the advantage of flexibilty e.g. this approach can be used with a schema registry, but you lose the any compile time type safety for your types.

Avrogen generates Elixir code from AVRO schemas, turning each record into module containing a `typedstruct` and a bunch of helper functions to encode and decode the struct to and from AVRO binary format.

For example, the following schema...
```json
{
  "type": "record",
  "namespace": "foo",
  "name": "Bar",
  "fields": [
    {"name": "baz", "type": ["null", "string"]},
    {"name": "qux", "type": "int"}
  ]
}
```

... generates an elxir module which looks like this:

```elixir
defmodule Foo.Bar do
  @moduledoc """

  Fields:
  `baz`: baz
  `qux`: qux

  """

  # This module was automatically generated from an AVRO schema.
  #
  # On occasion, the generated code exceeds Credo's complexity limits.
  # credo:disable-for-this-file
  @dialyzer :no_opaque

  use TypedStruct
  use Accessible

  # This line tells the Jason library how to encode the typedstruct below
  # With no arguments, this tells Jason to encode everything except the `:__struct__` field
  # See https://hexdocs.pm/jason/Jason.Encoder.html
  @derive Jason.Encoder

  typedstruct do
    field :baz, nil | String.t()
    field :qux, integer(), enforce: true
  end

  @behaviour Avrogen.AvroModule

  @impl true
  def avro_fqn(), do: "foo.Bar"

  @impl true
  def avro_schema_name(), do: "foo"

  @impl true
  def to_avro_map(%__MODULE__{} = r) do
    %{
      "baz" => r.baz,
      "qux" => r.qux
    }
  end

  @impl true
  def from_avro_map(%{
        "baz" => baz,
        "qux" => qux
      }) do
    {:ok,
     %__MODULE__{
       baz: baz,
       qux: qux
     }}
  end

  @expected_keys MapSet.new(["baz", "qux"])

  def from_avro_map(%{} = invalid) do
    actual = Map.keys(invalid) |> MapSet.new()
    missing = MapSet.difference(@expected_keys, actual) |> Enum.join(", ")
    {:error, "Missing keys: " <> missing}
  end

  def from_avro_map(_) do
    {:error, "Expected a map."}
  end

  @pii_fields MapSet.new([])

  def pii_fields(), do: @pii_fields

  def drop_pii(%__MODULE__{} = r) do
    m = Map.from_struct(r)

    Kernel.struct(__MODULE__, m)
  end

  alias Avrogen.Util.Random
  alias Avrogen.Util.Random.Constructors

  @spec random_instance(Random.rand_state()) :: {Random.rand_state(), struct()}
  def random_instance(rand_state) do
    Constructors.instantiate(rand_state, __MODULE__,
      baz: [Avrogen.Util.Random.Constructors.nothing(), Avrogen.Util.Random.Constructors.string()],
      qux: Avrogen.Util.Random.Constructors.integer()
    )
  end
end
```

## Usage

The easiest way to use avrogen is to add `:avro_code_generator` to your list of compilers in your `mix.exs` file, making sure to place it before the other compilers so all Elixir code is in place before the Elixir compiler runs.

```elixir
compilers: [:avro_code_generator | Mix.compilers()]
```

You'll also need to tell the elixir compiler to build the generated code, which can be acheived by adding the `generated` dir (the default destination directory) to your `elixirc_paths`.

```elixir
elixirc_paths: ["lib", "generated"]
```

Now, you can create a new directory called `schemas` at the root of your project and put some `.avsc` files in there. They will be built and compiled whenever things need to get recompiled, so just run your mix commands as usual.

### Options

While the defaults might be OK for some folks, you can configure the generator task from your mix.exs file, using the `avro_code_generator_opts` key.

E.g.
```elixir
avro_code_generator_opts: [
  paths: ["schemas/*.avsc"],
  dest: "generated",
  schema_root: "schema",
  module_prefix: "Avro"
]
```

The options are:
 - `paths` - an array of file paths or wildcards to locate schema files. Defaults to `"schemas/*.avsc"`.
 - `dest` - A directory of where to put the generated elixir code. Defaults to `"generated"`.
 - `schema_root` - The root of the schema directory, this is the root dir that will be used to resolve schemas located in other files. Defaults to `"schemas"`
 - `module_prefix` - Optional string to place at the front of generated elixir modules. Defaults to `"Avro"`.

### Using the generated code
Firstly, you'll need to start the Schema Registry process by adding the following entry to your Application file:

```elixir
@impl true
def start(_type, _args) do
  children = [
    ...
    # Start a schema registry
    {Avro.Schema.SchemaRegistry, Application.get_application(__MODULE__)},
    ...
  ]
  ...
end
```

Now you can create new records in code using the full module name, which is comprised of your prefix + the namespace + name of the record.

E.g. the record:
```json
{
  "namespace": "foo",
  "name": "Bar",
  "fields": [
    {"name": "quz", "type": ...}
  ]
}
```

... will result in a module called `Avro.Foo.Bar`, which can be used like any other normal struct:
```elixir
message = %Avro.Foo.Bar{quz: ...}
```

Encode this module to a binary using the `Avrogen.encode_schemaless/1` function:
```elixir
{:ok, bytes} = Avrogen.encode_schemaless(message)
```

You can decode it back into a struct using the `Avrogen.decode_schemaless/2` function, mind that you'll need to pass in the module name as avro binaries don't encode their type.
```elixir
{:ok, message} = Avrogen.decode_schemaless(Avro.Foo.Bar, bytes)
```

### Schema Resolution
Schemas commonly depend on other schemas, which can be located in a differnt file. Consider the following two schema files:

`hr.Developer.avsc`
```json
{
  "type": "record",
  "name": "Developer",
  "namespace": "hr",
  "fields": [
    {"name": "age", "type": "int"},
    {"name": "name", "type": "string"},
    {"name": "level", "type": "hr.Level"}
  ]
}
```

and

`hr.Level.avsc`
```json
{
  "type": "enum",
  "name": "Level",
  "namespace": "hr",
  "symbols": [
    "Intern",
    "Junior",
    "Senior",
    "Lead"
  ]
}
```

The `Developer` record refernces the `Level` enum using its fully qualified schema name: `hr.Level`. The filename must have the form `hr.Level.avsc` for it to be discovered correctly, otherwise you'll likely result in an error from the generator.

The `schema_root` option passed to the generator tells it where to search for such files.

## Publishing to Hexpm

Bump the version number in mix.exs using semver semantics and run:

```
mix hex.publish
```

You might need to sign into the primauk organization first, which is done like so:

```
mix hex.organization auth primauk
```

When prompted, use the credentials in the LastPass entry “Hex UK Shared Account”.
The username should be `uk-hex-shared@helloprima.com`

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc) and published on [HexDocs](https://hexdocs.pm). Once published, the docs can be found at <https://hexdocs.pm/avrogen>.

## Future Work
We should be able to do away with the schema registry and simply add `to_binary()` and `from_binary()` function calls into the generated code to go to and from binary. The avro spec is not too complex so this could be done fairly easily.

This would mean we don't have to run the schema registry as a seperate application, and the performance should be decent.
