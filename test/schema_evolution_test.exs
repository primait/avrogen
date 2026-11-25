defmodule Avrogen.SchemaEvolution.Test do
  @moduledoc """
  Tests to showcase the limitations of schema evolution using Avrogen.
  """

  use ExUnit.Case

  @basic_avsc """
  [
    {
      "type": "record",
      "name": "RecordWithString",
      "namespace": "record_with_string",
      "fields": [
        {
          "name": "string_field",
          "type": "string"
        }
      ]
    }
  ]
  """

  # adds a new field marked as nullable, but with no default
  # will be incompatible with the previous schema's data
  @evolved_incomp_avsc """
  [
    {
      "type": "record",
      "name": "RecordWithString",
      "namespace": "record_with_string",
      "fields": [
        {
          "name": "string_field",
          "type": "string"
        },
        {
          "name": "new_field",
          "type": ["null", "string"]
        }
      ]
    }
  ]
  """

  # gives the new field a default of null as well
  # will be compatible with the previous schema's data
  @evolved_comp_avsc """
  [
    {
      "type": "record",
      "name": "RecordWithString",
      "namespace": "record_with_string",
      "fields": [
        {
          "name": "string_field",
          "type": "string"
        },
        {
          "name": "new_field",
          "type": ["null", "string"],
          "default": null
        }
      ]
    }
  ]
  """

  test "basic evolution of adding a nullable field" do
    encoder_basic = make_encoder(@basic_avsc)
    decoder_basic = make_decoder(@basic_avsc)
    encoder_evolved_incomp = make_encoder(@evolved_incomp_avsc)
    decoder_evolved_incomp = make_decoder(@evolved_incomp_avsc)
    encoder_evolved_comp = make_encoder(@evolved_comp_avsc)
    decoder_evolved_comp = make_decoder(@evolved_comp_avsc)

    roundtripper = fn data, encoder, decoder ->
      fqn = "record_with_string.RecordWithString"
      decoder.(fqn, encoder.(fqn, data))
    end

    # 1) basic data roundtripped with basic schema is unchanged
    assert %{"string_field" => "mr"} ==
             roundtripper.(
               %{"string_field" => "mr"},
               encoder_basic,
               decoder_basic
             )

    # 2) basic data passed through backwards-compatible evolved schema is populated with missing nullable fields
    assert %{"string_field" => "mr", "new_field" => nil} ==
             roundtripper.(
               %{"string_field" => "mr"},
               encoder_evolved_comp,
               decoder_evolved_comp
             )

    # 3) basic data passed through backwards-incompatible evolved schema CRASHES
    assert_raise ErlangError, fn ->
      %{"string_field" => "mr", "new_field" => nil} ==
        roundtripper.(
          %{"string_field" => "mr"},
          encoder_evolved_incomp,
          decoder_evolved_incomp
        )
    end

    # 4) basic bytes encoded by basic schema are NOT decodable by backwards-compatible evolved schema :(
    assert_raise MatchError, fn ->
      %{"string_field" => "mr", "new_field" => nil} ==
        roundtripper.(
          %{"string_field" => "mr"},
          encoder_basic,
          decoder_evolved_comp
        )
    end
  end

  # Helper functions copied from SchemaRegistry
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
