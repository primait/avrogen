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

... generates a typedstruct which looks like this:

```elixir
defmodule Foo.Bar do
  use TypedStruct

  typedstruct do
    field :baz, nil | String.t()
    field :qux, integer(), enforce: true
  end

  # The actual generated module will contain a bunch of helper functions here which are subject to a lot of churn and thus have been redacted for brevity

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

### PII Fields
Avrogen introduces an unofficial extension to AVRO schema specification which can be used to mark record's fields as PII (Personally Identifiable Information). Each generated record module gets a `drop_pii/1` function which recursively strips away all fields marked as PII in the record, and any records contained within.

Mark a field as PII by adding `pii: true` option to the field. For example imagine you are storing names and ages of people, and the name is PII (but the age isn't).

```json
{
  "type": "record",
  "name": "Person",
  "namespace": "example",
  "fields": [
    {"name": "name", "type": ["null", "string"], "pii": true},
    {"name": "age", "type": "int"}
  ]
}
```
Then you can simply call `drop_pii/1` on your record to replace all the PII fields with `nil` like so:

```elixir
ex> person = %Avro.Example.Person{name: "John Smith", age: 38} 
%Avro.Example.Person{age: 38, name: "John Smith"}

ex> Avro.Example.Person.drop_pii(person)
%Avro.Example.Person{age: 38, name: nil}
```

> Note: Fields marked as PII must be of a union type containing a null.

The AVRO spec specifies that any extra fields in schemas are ignored, so schemas containing this extension are backwards compatible with other AVRO parsers, as they will just ignore this field.

### Random Instance Generators
Each generated module contains a function to create a random instance of the record/enum. This can be useful for fuzz testing, among other things.

E.g. Using the `Person` example above, the generated module will contain the following function:
```elixir
def random_instance(rand_state) do
  # ...
end
```

> The function expects to be given an erlang random state type object, which can be seeded in one of many ways depending on what you want to do with it. The simplest way to create this random state is to generate it with the default generator - `:rand.seed(:default)`, as demonstrated below.

You can use this `random_instance/1` function to generate random instances of the module's struct, for example:
```elixir
iex> state = :rand.seed(:default)
iex> {state, person} = Avro.Example.Person.random_instance(state)
{
  # ~~snip~~ 
  %Avro.Foo.Bar{
    name: <<29, 120, 54, 75, 84, 54, 70, 29, 48, 68, 87, 87>>,
    age: 1812334491
  }
}
```

In this example, `person` is a random instance of the Avro.Example.Person record, and `state` is the mutated state which can be used again to pass to the next call to `random_instance/1`.

The different types produce random values according to different rules:

- Unions produce a random instance of any one of the types of the union, where each type is equally likely to be chosen.
- Strings produce a random utf8 binary of up to 1000 codepoints, each of which lie in the range `0 <= codepoint < 10,000` by default.
- Integers and doubles produce a random value in the range `-2,147,483,648 <= value < 2,147,483,648` by default.
- Enums produce one of their symbols selected at random, with each symbol having an equal probability of showing up.
- Arrays produce a random array of up to 10 elements, where the value of each element is a random instance of the array's element type according to the above rules.
- Records produce a random instance of that record, where each field of the record is generated randomly according to the above rules.

You can control how random you really want these random instances to be using some more unofficial extensions to the avro spec. For example, you can specify the max and min values of int type fields using the "range" specifier like so:

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

Now when you call `random_instance/1`, the age field will be limited to the range `16 <= age < 80`.

Strings can be formatted according to semantic formatting. Currently the only supported type is "postcode", but support for more types may well be added in the future.

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

Now, the postcode field will be limited to random postcodes (e.g. `BS23 7SX`), rather than completely random strings.

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
