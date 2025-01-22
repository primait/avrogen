defmodule Avrogen.Avro.Types.LogicalTypesTest.MacroSupport do
  alias Avrogen.Avro.Schema.CodeGenerator
  alias Avrogen.Avro.Types.Logical
  alias Avrogen.Utils.MacroUtils

  @logical_types_map %{
    :decimal => %Logical.Decimal{precision: 2, scale: 1},
    :decimal_string => %Logical.DecimalString{},
    :uuid => %Logical.UUID{},
    :date_string => %Logical.DateString{},
    :date => %Logical.Date{},
    :datetime_string => %Logical.DateTimeString{},
    :time_millis => %Logical.TimeMillis{},
    :time_micros => %Logical.TimeMicros{},
    :timestamp_millis => %Logical.TimestampMillis{},
    :timestamp_micros => %Logical.TimestampMicros{},
    :local_timestamp_millis => %Logical.LocalTimestampMillis{},
    :local_timestamp_micros => %Logical.LocalTimestampMicros{}
  }

  defmacro gen_code do
    details =
      @logical_types_map
      |> Enum.map(fn {type, module} ->
        [
          CodeGenerator.decode_function(module, :"decode_#{type}", %{}),
          CodeGenerator.encode_function(module, :"encode_#{type}", %{})
        ]
      end)
      |> Enum.flat_map(&MacroUtils.flatten_block/1)

    quote(do: (unquote_splicing(details)))
  end
end

defmodule Avrogen.Avro.Types.LogicalTypesTest do
  use ExUnit.Case, async: true
  alias __MODULE__.MacroSupport
  require MacroSupport

  MacroSupport.gen_code()

  describe "logical types module can be encoded and decoded" do
    test "a decimal value expressed as a string" do
      assert {:error, _} = decode_decimal_string("test")

      decimal = Decimal.new("1.2")
      assert {:ok, ^decimal} = decode_decimal_string("1.2")

      assert_raise FunctionClauseError, fn -> encode_decimal_string("test") end

      assert "1.2" = encode_decimal_string(decimal)
    end

    test "a decimal value expressed as bytes" do
      assert {:error, _} = decode_decimal(1)

      decimal = Decimal.new("2.1")
      assert {:ok, ^decimal} = decode_decimal(<<21>>)

      assert_raise FunctionClauseError, fn -> encode_decimal(1) end

      assert <<21>> = encode_decimal(decimal)
    end

    test "a uuid value expressed as string" do
      assert {:error, _} = decode_uuid("test")

      uuid = Uniq.UUID.uuid4()
      assert {:ok, ^uuid} = decode_uuid(uuid)

      assert_raise ArgumentError, fn ->
        encode_uuid("test")
      end

      assert ^uuid = encode_uuid(uuid)
    end

    test "a date value expressed as a string" do
      assert {:error, _} = decode_date_string("test")

      date = ~D[2024-06-28]
      date_string = "2024-06-28"
      assert {:ok, ^date} = decode_date_string(date_string)

      assert_raise FunctionClauseError, fn -> encode_date_string("test") end

      assert ^date_string = encode_date_string(date)
    end

    test "a date value expressed as int" do
      date_int = 19_902
      assert {:error, _} = decode_date(to_string(date_int))

      date = ~D[2024-06-28]
      assert {:ok, ^date} = decode_date(date_int)

      assert_raise FunctionClauseError, fn -> encode_date(to_string(date_int)) end

      assert ^date_int = encode_date(date)
    end

    test "a datetime value expressed as string" do
      assert {:error, _} = decode_datetime_string("test")

      date = ~U[2024-06-28 11:15:30.000Z]
      date_string = "2024-06-28T11:15:30.000Z"
      assert {:ok, ^date} = decode_datetime_string(date_string)

      assert_raise FunctionClauseError, fn -> encode_datetime_string("test") end

      assert ^date_string = encode_datetime_string(date)
    end

    test "a time-millis value expressed as int" do
      time_millis = 40_530_000

      assert {:error, _} = decode_time_millis(to_string(time_millis))

      time = ~T[11:15:30.000]
      assert {:ok, ^time} = decode_time_millis(time_millis)

      assert_raise FunctionClauseError, fn ->
        encode_time_millis(to_string(time_millis))
      end

      assert ^time_millis = encode_time_millis(time)
    end

    test "a time-micros value expressed as long" do
      time_micros = 40_530_000_000

      assert {:error, _} = decode_time_micros(to_string(time_micros))

      time = ~T[11:15:30.000000]
      assert {:ok, ^time} = decode_time_micros(time_micros)

      assert_raise FunctionClauseError, fn ->
        encode_time_micros(to_string(time_micros))
      end

      assert ^time_micros = encode_time_micros(time)
    end

    test "a timestamp-millis value expressed as long" do
      timestamp_millis = 1_719_573_330_123

      assert {:error, _} = decode_timestamp_millis(to_string(timestamp_millis))

      timestamp = ~U[2024-06-28 11:15:30.123Z]
      assert {:ok, ^timestamp} = decode_timestamp_millis(timestamp_millis)

      assert_raise FunctionClauseError, fn ->
        encode_timestamp_millis(to_string(timestamp_millis))
      end

      assert ^timestamp_millis = encode_timestamp_millis(timestamp)
    end

    test "a timestamp-micros value expressed as long" do
      timestamp_micros = 1_719_573_330_123_456

      assert {:error, _} = decode_timestamp_micros(to_string(timestamp_micros))

      timestamp = ~U[2024-06-28 11:15:30.123456Z]
      assert {:ok, ^timestamp} = decode_timestamp_micros(timestamp_micros)

      assert_raise FunctionClauseError, fn ->
        encode_timestamp_micros(to_string(timestamp_micros))
      end

      assert ^timestamp_micros = encode_timestamp_micros(timestamp)
    end

    test "a local-timestamp-millis value expressed as long" do
      timestamp_millis = 1_719_573_330_123

      assert {:error, _} = decode_local_timestamp_millis(to_string(timestamp_millis))

      timestamp = ~N[2024-06-28 11:15:30.123000]
      assert {:ok, ^timestamp} = decode_local_timestamp_millis(timestamp_millis)

      assert_raise FunctionClauseError, fn ->
        encode_local_timestamp_millis(to_string(timestamp_millis))
      end

      assert ^timestamp_millis = encode_local_timestamp_millis(timestamp)
    end

    test "a local-timestamp-micros value expressed as long" do
      timestamp_micros = 1_719_573_330_123_456

      assert {:error, _} = decode_local_timestamp_micros(to_string(timestamp_micros))

      timestamp = ~N[2024-06-28 11:15:30.123456]
      assert {:ok, ^timestamp} = decode_local_timestamp_micros(timestamp_micros)

      assert_raise FunctionClauseError, fn ->
        encode_local_timestamp_micros(to_string(timestamp_micros))
      end

      assert ^timestamp_micros = encode_local_timestamp_micros(timestamp)
    end
  end
end
