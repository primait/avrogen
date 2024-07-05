defmodule Avrogen.Avro.Types.Logical do
  @moduledoc """
    This module delegates the parsing logic to the specific Logical types modules.

    [Logical types](https://avro.apache.org/docs/1.11.0/spec.html#Logical+Types)

    A logical type is an Avro primitive or complex type with extra attributes to represent
    a derived type. The attribute logicalType must always be present for a logical type, and
    is a string with the name of one of the logical types listed later in this section.
    Other attributes may be defined for particular logical types.

    A logical type is always serialized using its underlying Avro type so that values are
    encoded in exactly the same way as the equivalent Avro type that does not have a
    logicalType attribute. Language implementations may choose to represent logical types
    with an appropriate native type, although this is not required.

    Language implementations must ignore unknown logical types when reading, and should use
    the underlying Avro type. If a logical type is invalid, for example a decimal with scale
    greater than its precision, then implementations should ignore the logical type and use
    the underlying Avro type.
  """

  @type t ::
          __MODULE__.DecimalString.t()
          | __MODULE__.Decimal.t()
          | __MODULE__.UUID.t()
          | __MODULE__.DateString.t()
          | __MODULE__.Date.t()
          | __MODULE__.DateTimeString.t()
          | __MODULE__.TimeMillis.t()
          | __MODULE__.TimeMicros.t()
          | __MODULE__.TimestampMillis.t()
          | __MODULE__.TimestampMicros.t()
          | __MODULE__.LocalTimestampMillis.t()
          | __MODULE__.LocalTimestampMicros.t()

  def parse(value), do: module(value).parse(value)

  @spec module(map()) :: module()
  def module(%{"logicalType" => "decimal", "type" => "string"}), do: __MODULE__.DecimalString
  def module(%{"logicalType" => "decimal", "type" => "bytes"}), do: __MODULE__.Decimal
  def module(%{"logicalType" => "big_decimal", "type" => "string"}), do: __MODULE__.DecimalString

  def module(%{"logicalType" => "uuid", "type" => "string"}), do: __MODULE__.UUID

  def module(%{"logicalType" => "date", "type" => "string"}), do: __MODULE__.DateString
  def module(%{"logicalType" => "date", "type" => "int"}), do: __MODULE__.Date

  def module(%{"logicalType" => "datetime", "type" => "string"}), do: __MODULE__.DateTimeString
  def module(%{"logicalType" => "iso_date", "type" => "string"}), do: __MODULE__.DateString

  def module(%{"logicalType" => "iso_datetime", "type" => "string"}),
    do: __MODULE__.DateTimeString

  def module(%{"logicalType" => "time-millis", "type" => "int"}), do: __MODULE__.TimeMillis
  def module(%{"logicalType" => "time-micros", "type" => "long"}), do: __MODULE__.TimeMicros

  def module(%{"logicalType" => "timestamp-millis", "type" => "long"}),
    do: __MODULE__.TimestampMillis

  def module(%{"logicalType" => "timestamp-micros", "type" => "long"}),
    do: __MODULE__.TimestampMicros

  def module(%{"logicalType" => "local-timestamp-millis", "type" => "long"}),
    do: __MODULE__.LocalTimestampMillis

  def module(%{"logicalType" => "local-timestamp-micros", "type" => "long"}),
    do: __MODULE__.LocalTimestampMicros
end
