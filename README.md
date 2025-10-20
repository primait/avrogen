# Avrogen

[![Build Status](https://github.com/primait/avrogen/actions/workflows/elixir.yml/badge.svg)](https://github.com/primait/avrogen/actions/workflows/elixir.yml)
[![Hex.pm](https://img.shields.io/badge/hex.pm-green)](https://hex.pm/packages/prima/avrogen)
[![Documentation](https://img.shields.io/badge/documentation-gray)](https://prima.hexdocs.pm/avrogen/)

Generate Elixir typedstructs and various useful helper functions from AVRO
schemas at compile time.

## Rationale

While there exists a handful of libraries to encode and decode AVRO messages in
Elixir, all of them consume schemas at runtime, which has the advantage of
flexibilty e.g. this approach can be used with a schema registry, but you lose
the any compile time type safety for your types.

Avrogen generates Elixir code from AVRO schemas, turning each record into module
containing a `typedstruct` and a bunch of helper functions to encode and decode
the struct to and from AVRO binary format.

For example, the following schema...

```json
{
  "type": "record",
  "namespace": "foo",
  "name": "Bar",
  "fields": [
    { "name": "baz", "type": ["null", "string"] },
    { "name": "qux", "type": "int" }
  ]
}
```

... generates a module `foo/Bar.ex` which (with documentation and various bits
of implementation omitted for the sake of brevity) looks like this:

```elixir
defmodule Avro.Foo.Bar do
  use TypedStruct
  
  @expected_keys MapSet.new(["baz", "qux"])
  @pii_fields MapSet.new([])

  typedstruct do
    field :baz, nil | String.t()
    field :qux, integer(), enforce: true
  end

  def avro_fqn(), do: "foo.Bar"
  def to_avro_map(...) do ... end
  def from_avro_map(...) do ... end
  def pii_fields(), do: @pii_fields
  def drop_pii(...) do ... end
  def random_instance(rand_state) do ... end
end
```

The main feature here is the `typedstruct`, which allows us to initialize this
module using the struct syntax:

```elixir
%Avro.Foo.Bar{
  baz: "quux",
  qux: 12
}
```

The other helper functions provide extra functionality which are explained
below.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `avrogen` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:avrogen, "~> 0.4.3", organization: "prima"}
  ]
end
```

## Usage

The easiest way to use avrogen is to add `:avro_code_generator` to your list of
compilers in your `mix.exs` file, making sure to place it before the other
compilers so all Elixir code is in place before the Elixir compiler runs.

```elixir
compilers: [:avro_code_generator | Mix.compilers()]
```

You'll also need to tell the elixir compiler to build the generated code, which
can be acheived by adding the `generated` dir (the default destination
directory) to your `elixirc_paths`.

```elixir
elixirc_paths: ["lib", "generated"]
```

Now, you can create a new directory called `schemas` at the root of your project
and put some `.avsc` files in there. They will be built and compiled whenever
things need to get recompiled, so just run your mix commands as usual.

### Options

While the defaults might be OK for some folks, you can configure the generator
task from your mix.exs file, using the `avro_code_generator_opts` key.

E.g.

```elixir
avro_code_generator_opts: [
  paths: ["schemas/*.avsc"],
  dest: "generated",
  schema_root: "schema",
  module_prefix: "Avro",
  scoped_embed_paths: ["priv/schema/events.*.avsc"],
  schema_resolution_mode: :flat
]
```

The options are:

- `paths` - an array of file paths or wildcards to locate schema files. Defaults
  to `"schemas/*.avsc"`.
- `dest` - A directory of where to put the generated elixir code. Defaults to
  `"generated"`.
- `schema_root` - The root of the schema directory, this is the root dir that
  will be used to resolve schemas located in other files. Defaults to
  `"schemas"`
- `module_prefix` - String to place at the front of generated elixir modules.
  Defaults to `"Avro"`.
- `schema_resolution_mode` - Tells the code generator how to resolve external
  schemas to a filename. Defaults to `:flat`.
- `scope_embed_paths` - the glob patterns of the files where any embedded scopes
  should have the generated module path contain the encompasing types.

  For example, for the following schema

  ```json
  {
    "name": "Event",
    "namespace": "events",
    "type": "record",
    "fields": [
      {
        "name": "details",
        "type": {
          "name": "Subtype",
          "type": "record",
          "fields": [
            ...
          ]
        }
      }
    ]
  }
  ```

  If this file is included in the scoped_embed_paths, then the generated module
  for `Subtype` would be called `Events.Event.Subtype` otherwise it would be
  `Events.Subtype`. This option is useful when you have naming clashes in
  embedded schema subtypes, or if you simply want to namespace subtypes to avoid
  potential future clashes

### Using the generated code

Firstly, you'll need to start the Schema Registry process by adding the
following entry to your Application file:

```elixir
@impl true
def start(_type, _args) do
  children = [
    ...
    # Start a schema registry
    {Avrogen.Schema.SchemaRegistry, Application.get_application(__MODULE__)},
    ...
  ]
  ...
end
```

Now you can create new records in code using the full module name, which is
comprised of your prefix + the namespace + name of the record.

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

... will result in a module called `Avro.Foo.Bar`, which can be used like any
other normal struct:

```elixir
message = %Avro.Foo.Bar{quz: ...}
```

Encode this module to a binary using the `Avrogen.encode_schemaless/1` function:

```elixir
{:ok, bytes} = Avrogen.encode_schemaless(message)
```

You can decode it back into a struct using the `Avrogen.decode_schemaless/2`
function, mind that you'll need to pass in the module name as avro binaries
don't encode their type.

```elixir
{:ok, message} = Avrogen.decode_schemaless(Avro.Foo.Bar, bytes)
```

### Converting to JSON

Each generated module comes with the `@derive Jason.Encoder` attribute, which
tells JSON that the struct can be encoded by simply serializing everything other
than the `__struct__` field. See https://hexdocs.pm/jason/Jason.Encoder.html for
more details.

Thus, converting a message to JSON is as simple as:

```elixir
iex> message = %Avro.Test.Person{name: "Dave", age: 37}
iex> Jason.encode(message)
{:ok, "{\"age\":37,\"name\":\"Dave\"}"}
```

> Note: This is not the same as the official AVRO JSON encoding spec, and is
> mainly used for debugging / making messages human readable.

### External Schema Resolution

Schemas commonly depend on other schemas, which can be located in a different
file.

The code generator has two different modes for file resolution: tree mode and
flat mode.

Both modes work from a root directory passed in via the `schema_root` code
generator option (see above).

In `:flat` mode, schemas are expected to be a flat list of files in the root dir
like so:

```
name.space.SchemaName -> root/name.space.SchemaName.avsc
```

This is how libraries like python's `fastavro` expect schemas to be laid out.

In `:tree` mode, the namespace is split into directories like so:

```
name.space.SchemaName -> root/name/space/SchemaName.avsc
```

This is how libraries like `avrora` expect schemas to be laid out.

### Types

The table below lists supported primitive AVRO types, and their corresponding
Elixir type:

| AVRO Type | Elixir Type                    |
| --------- | ------------------------------ |
| `null`    | `nil`                          |
| `int`     | `integer`                      |
| `double`  | `float`                        |
| `string`  | `String.t()`                   |
| `bytes`   | `binary`                       |
| `array`   | `list`                         |
| `map`     | `%{ String.t() => Value.t() }` |

The following logical types are also supported:

| AVRO Logical Type        | AVRO Underlying Type | Elixir Type     |
| ------------------------ | -------------------- | --------------- |
| `uuid`                   | `string`             | `String`        |
| `big_decimal`            | `string`             | `Decimal`       |
| `big-decimal`            | `string`             | `Decimal`       |
| `decimal`                | `string`             | `Decimal`       |
| `decimal`                | `bytes`              | `Decimal`       |
| `date`                   | `int`                | `Date`          |
| `date`                   | `string`             | `Date`          |
| `iso_date`               | `string`             | `Date`          |
| `datetime`               | `string`             | `DateTime`      |
| `iso_datetime`           | `string`             | `DateTime`      |
| `time-millis`            | `int`                | `Time`          |
| `time-micros`            | `long`               | `Time`          |
| `timestamp-millis`       | `long`               | `DateTime`      |
| `timestamp-micros`       | `long`               | `DateTime`      |
| `local-timestamp-millis` | `long`               | `NaiveDateTime` |
| `local-timestamp-micros` | `long`               | `NaiveDateTime` |

The following AVRO types are not supported (yet):

- `float` (use `double`)
- `long` (use `int`)
- `fixed`

### PII Fields

Avrogen introduces an unofficial extension to AVRO schema specification which
can be used to mark record's fields as PII (Personally Identifiable
Information). Each generated record module gets a `drop_pii/1` function which
recursively strips away all fields marked as PII in the record, and any records
contained within.

Mark a field as PII by adding `pii: true` option to the field. For example
imagine you are storing names and ages of people, and the name is PII (but the
age isn't).

```json
{
  "type": "record",
  "name": "Person",
  "namespace": "example",
  "fields": [
    { "name": "name", "type": ["null", "string"], "pii": true },
    { "name": "age", "type": "int" }
  ]
}
```

Then you can simply call `drop_pii/1` on your record to replace all the PII
fields with `nil` like so:

```elixir
ex> person = %Avro.Example.Person{name: "John Smith", age: 38} 
%Avro.Example.Person{age: 38, name: "John Smith"}

ex> Avro.Example.Person.drop_pii(person)
%Avro.Example.Person{age: 38, name: nil}
```

> Note: Fields marked as PII must be of a union type containing a null.

The AVRO spec specifies that any extra fields in schemas are ignored, so schemas
containing this extension are backwards compatible with other AVRO parsers, as
they will just ignore this field.

### Random Instance Generators

Each generated module contains a function to create a random instance of the
record/enum. This can be useful for fuzz testing, among other things.

E.g. Using the `Person` example above, the generated module will contain the
following function:

```elixir
def random_instance(rand_state) do
  # ...
end
```

> The function expects to be given an erlang random state type object, which can
> be seeded in one of many ways depending on what you want to do with it. The
> simplest way to create this random state is to generate it with the default
> generator - `:rand.seed(:default)`, as demonstrated below.

You can use this `random_instance/1` function to generate random instances of
the module's struct, for example:

```elixir
iex> state = :rand.seed(:default)
iex> {state, person} = Avro.Example.Person.random_instance(state)
iex> person
%Avro.Foo.Bar{
  name: <<29, 120, 54, 75, 84, 54, 70, 29, 48, 68, 87, 87>>,
  age: 1812334491
}
```

In this example, `person` is a random instance of the Avro.Example.Person
record, and `state` is the mutated state which can be used again to pass to the
next call to `random_instance/1`.

The various types produce random values according to the following rules:

| Type                                          | Rule                                                                                                                |
| --------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| `null`                                        | Always produces `nil`.                                                                                              |
| `union`                                       | Random instance of any of the types within the union, where each type is equally likely to be chosen.               |
| `string`                                      | Random utf8 binary of up to 1000 codepoints, where each codepoint lies in the range `0 <= codepoint < 10,000`.      |
| `int`, `double`, `big_decimal`, `big-decimal` (logical type) | Random value in the range `-2,147,483,648 <= value < 2,147,483,648`.                                                |
| `iso_date` and `iso_datetime` (logical types) | Random value in the range `1970-01-01T00:00:00 <= value < 2045-01-01T00:00:00`.                                     |
| `enum`                                        | One of the symbols selected at random, with each symbol having an equal probability of showing up.                  |
| `array`                                       | Random list of up to 10 elements, where the value of each element is a random instance of the array's element type. |
| `record`                                      | Random instance of that record, where each field of the record is generated randomly according to the above rules.  |

You can control how random you really want these random instances to be using
some more unofficial extensions to the avro spec. For example, you can specify
the max and min values of int type fields using the "range" specifier like so:

```json
{
  "name": "age",
  "type": "int",
  "range": {
    "int": {
      "max": 80,
      "min": 16
    }
  }
}
```

Now when you call `random_instance/1`, the age field will be limited to the
range `16 <= age < 80`.

Strings can be formatted according to semantic formatting. Currently the only
supported type is "postcode", but support for more types may well be added in
the future.

E.g.

```json
{
  "name": "postcode",
  "type": "string",
  "range": {
    "string": {
      "semantic_type": "postcode"
    }
  }
}
```

Now, the postcode field will be limited to random postcodes (e.g. `BS23 7SX`),
rather than completely random strings.

## Schema Generation

AVRO's avsc format is not always the easiest format to maintain. Because it uses
JSON, variables and comments are not allowed. Thus, `avrogen` comes with a
schema generator tool to help ease the process.

This tool can be optionally used by adding it to the list of compilers for your
project's `mix.exs` file like so:

```elixir
compilers: [:avro_schema_generator | Mix.compilers()]
```

Note: If you are also using the `avro_code_generator`, then you will need to put
the schema generator before the code generator, as the code generator requires
schemas in order to do its job.

Then, also in your `mix.exs` file, configure the code generator using the
following options:

```elixir
avro_schema_generator_opts: [
  paths: ["exs_schemas/**/*.exs"],
  dest: "schemas",
  schema_resolution_mode: :flat
],
```

Where the options are as follows:

- `paths`: A wildcard expression which matches the location of your schema
  definition files. Defaults to `exs_schemas/**/*.exs`.
- `dest`: Where to put generated schema files. Defaults to `schemas`.
- `schema_resolution_mode`: How to structure the dest dir (see the schema
  resolution section above). Options are `:flat` or `:tree`. Defaults to
  `:flat`.

So what goes in these schema definition files? All files should contain a single
module which implements the `Avrogen.Schema.SchemaModule` behaviour. For
example:

```elixir
defmodule Person do
  alias Avrogen.Schema.SchemaModule
  @behaviour SchemaModule
  @impl SchemaModule
  def schema_name(), do: "application_data.v2"

  @impl SchemaModule
  def avsc(), do: avro_schema()

  # "type": "record",
  # "name": "Person",
  # "namespace": "example",
  # "fields": [
  #   {"name": "name", "type": ["null", "string"], "pii": true},
  #   {"name": "age", "type": "int"}
  # ]

  @person %{
    type: :record,
    name: "Person ",
    namespace: "example",
    doc: "Describes a person.",
    fields: [
      %{
        name: :name,
        type: [:null, :string],
        doc: """
        The name of the person.
        """
      },
      %{
        name: :age,
        type: :int,
        doc: """
        The age of the person.
        """
      }
    ]
  }

  @avro_spec [
    @person
  ]

  def avro_schema() do
    Jason.encode!(@avro_spec)
  end

  @impl SchemaModule
  def avro_schema_elixir() do
    @avro_spec
  end
end
```

When you next compile the code with e.g. `mix compile`, the following avsc
schema will be generated:

```json
{
  "doc": "Describes a person.",
  "fields": [
    {
      "doc": "The name of the person.\n",
      "name": "name",
      "type": [
        "null",
        "string"
      ]
    },
    {
      "doc": "The age of the person.\n",
      "name": "age",
      "type": "int"
    }
  ],
  "name": "Person ",
  "namespace": "example",
  "type": "record"
}
```

There's not much magic here, but it should be evident how elixir variables and
constructs can be used to reduce repetition in the definitions of the schemas.
It's worth noting that these schema definitions are used to define lists of
schemas in one go. Each individual schema is pulled out and placed into the
target destination, and the file name is structured like so:
`<dest>/<namespace>.<name>.avsc`, which is the appropriate format for the avro
code generator to use later down the line.

Note that once you enable this tool, it completely takes over the `dest`
directory, so any other files found in here will most likely be removed.

## Using with Avrora

Avrora is an Elixir library for encoding/decoding avro messages, with options to
integrate with a schema registry.

Avrora can work in conjunction with avrogen quite nicely, with avrogen
generating the elixir code, and avrora handling communication with the schema
registry and encoding/decoding of messages.

Avrogen expects schemas to be stored in the filesystem in a "tree" style format,
so make sure to set the option `schema_resolution_mode` to `:tree` for both
generators. Once you have configured the avrora cache (see docs on their
[README](https://hexdocs.pm/avrora/readme.html#usage)), you can then use
avrogen's typedstructs to create the messages and do some basic type/key
checking, and avrora to encode/decode the messages.

For example, to encode...

```elixir
%module{} = message = %Avro.Test.Person{name: "John Smith", age: 38}
name = module.avro_fqn()
map = module.to_avro_map(message)
{:ok, bytes} = Avrora.encode(map, schema_name: name)
# Do something with the bytes
```

... and then to decode ...

```elixir
{:ok, [decoded]} = Avrora.decode(bytes, schema_name: Avro.Test.Person.avro_fqn())
{:ok, message} = Avro.Test.Person.from_avro_map(decoded)
# Do something with the message
```

> Note: Of course, this assumes you know the decoded message type ahead of time.
> You can ask Avrora to infer the message type using magic headers by calling
> `decode/1` rather than `decode/2` (omitting the `schema_name` option), but it
> doesn't disclose the inferred schema name to the caller, which is not
> particularly useful.
