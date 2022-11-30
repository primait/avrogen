defmodule Avro do
  @moduledoc """
  Provides functions for encoding and decoding avro records.

  Kafka has another approach to schemaless, which prepends a schema ID -- to be
  investigated; hopefully we can sort out the seeming incompatibilities at some
  point, once and for all, without too many workarounds.

  The proper approach is either:
    - prepend C3 01 + 8 byte fingerprint to the binary (Avro single-object
      encoding)
    - prepend 00 + 4 byte schema ID (Confluent Schema Registry Wire Format)

  Finally, the same message is encoded differently in Python and in Elixir
  (fastavro appears to have trouble roundtripping records). The decoded
  versions largely agree, but have some subtle differences. This needs to be
  investigated. It might require some small schema tweaks to avoid this kind of
  situation.
  """
  import HappyWith

  alias Avro.Schema.SchemaRegistry

  def encode_schemaless(%module{} = record) do
    encoder = SchemaRegistry.get_encoder()
    intermediate = module.to_avro_map(record)
    bytes_io_data = encoder.(module.avro_fqn(), intermediate)
    {:ok, bytes_io_data}
  rescue
    e -> {:error, Exception.format(:error, e, __STACKTRACE__)}
  end

  def encode_schemaless_base64(%_{} = record) do
    record
    |> encode_schemaless()
    |> Noether.Either.map(fn iodata ->
      iodata
      |> IO.iodata_to_binary()
      |> Base.encode64()
    end)
  end

  def decode_schemaless(module, bytes_io_data) do
    decoder = SchemaRegistry.get_decoder()
    intermediate = decoder.(module.avro_fqn(), bytes_io_data)
    module.from_avro_map(intermediate)
  rescue
    e -> {:error, Exception.format(:error, e, __STACKTRACE__)}
  end

  def decode_schemaless_base64(module, base64_schemaless_avro_bytes) do
    happy_with do
      {:ok, binary} <- Base.decode64(base64_schemaless_avro_bytes)
      decode_schemaless(module, binary)
    else
      :error ->
        {:error, :invalid_base64}
    end
  end
end
