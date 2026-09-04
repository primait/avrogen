defmodule Avrogen.Util.TimeTest do
  use ExUnit.Case
  use ExUnitProperties

  import StreamData

  alias Avrogen.Util.Time, as: AvrogenTime

  @millis_per_second 1_000
  @seconds_per_day 86_400
  @millis_per_day @seconds_per_day * @millis_per_second

  defp date_generator do
    map(
      integer(-3650..3650),
      &Date.add(~D[2000-01-01], &1)
    )
  end

  defp date_tuple_generator do
    map(date_generator(), &Date.to_erl/1)
  end

  defp time_generator do
    map(
      integer(0..86_399_999),
      &Time.add(~T[00:00:00], &1, :millisecond)
    )
  end

  defp naive_datetime_generator do
    map(
      integer((-3650 * @seconds_per_day)..(3650 * @seconds_per_day)),
      &NaiveDateTime.add(~N[2000-01-01 00:00:00], &1, :second)
    )
  end

  defp datetime_generator do
    map(
      naive_datetime_generator(),
      &DateTime.from_naive!(&1, "Etc/UTC")
    )
  end

  defp datetime_tuple_generator do
    map(
      naive_datetime_generator(),
      &NaiveDateTime.to_erl/1
    )
  end

  #
  # compare/2
  #

  describe "compare/2" do
    test "returns :eq for equal values" do
      date = ~D[2000-01-01]
      time = ~T[12:34:56]
      naive_datetime = ~N[2000-01-01 12:34:56]
      datetime = DateTime.from_naive!(naive_datetime, "Etc/UTC")

      assert AvrogenTime.compare(time, time) == :eq
      assert AvrogenTime.compare(date, date) == :eq
      assert AvrogenTime.compare(naive_datetime, naive_datetime) == :eq
      assert AvrogenTime.compare(datetime, datetime) == :eq
      assert AvrogenTime.compare({2000, 1, 1}, {2000, 1, 1}) == :eq

      assert AvrogenTime.compare({{2000, 1, 1}, {12, 34, 56}}, {{2000, 1, 1}, {12, 34, 56}}) ==
               :eq
    end

    property "orders Time values correctly" do
      check all(
              t1 <- time_generator(),
              t2 <- time_generator()
            ) do
        assert AvrogenTime.compare(t1, t2) == Time.compare(t1, t2)
      end
    end

    property "orders Date values correctly" do
      check all(
              t1 <- date_generator(),
              t2 <- date_generator()
            ) do
        assert AvrogenTime.compare(t1, t2) == Date.compare(t1, t2)
      end
    end

    property "orders NaiveDateTime values correctly" do
      check all(
              t1 <- naive_datetime_generator(),
              t2 <- naive_datetime_generator()
            ) do
        assert AvrogenTime.compare(t1, t2) == NaiveDateTime.compare(t1, t2)
      end
    end

    property "orders DateTime values correctly" do
      check all(
              t1 <- datetime_generator(),
              t2 <- datetime_generator()
            ) do
        assert AvrogenTime.compare(t1, t2) == DateTime.compare(t1, t2)
      end
    end

    property "orders Date tuples correctly" do
      check all(
              t1 <- date_tuple_generator(),
              t2 <- date_tuple_generator()
            ) do
        expected =
          Date.compare(
            Date.from_erl!(t1),
            Date.from_erl!(t2)
          )

        assert AvrogenTime.compare(t1, t2) == expected
      end
    end

    property "orders datetime tuples correctly" do
      check all(
              t1 <- datetime_tuple_generator(),
              t2 <- datetime_tuple_generator()
            ) do
        expected =
          NaiveDateTime.compare(
            NaiveDateTime.from_erl!(t1),
            NaiveDateTime.from_erl!(t2)
          )

        assert AvrogenTime.compare(t1, t2) == expected
      end
    end
  end

  #
  # diff_millis/2
  #

  describe "diff_millis/2" do
    test "returns zero for equal values" do
      date = ~D[2000-01-01]
      time = ~T[12:34:56]
      naive_datetime = ~N[2000-01-01 12:34:56]
      datetime = DateTime.from_naive!(naive_datetime, "Etc/UTC")

      assert AvrogenTime.diff_millis(time, time) == 0
      assert AvrogenTime.diff_millis(date, date) == 0
      assert AvrogenTime.diff_millis(naive_datetime, naive_datetime) == 0
      assert AvrogenTime.diff_millis(datetime, datetime) == 0
      assert AvrogenTime.diff_millis({2000, 1, 1}, {2000, 1, 1}) == 0

      assert AvrogenTime.diff_millis(
               {{2000, 1, 1}, {12, 34, 56}},
               {{2000, 1, 1}, {12, 34, 56}}
             ) == 0
    end

    property "matches Time.diff/3" do
      check all(
              t1 <- time_generator(),
              t2 <- time_generator()
            ) do
        assert AvrogenTime.diff_millis(t1, t2) ==
                 Time.diff(t1, t2, :millisecond)
      end
    end

    property "matches Date.diff/2 converted to milliseconds" do
      check all(
              t1 <- date_generator(),
              t2 <- date_generator()
            ) do
        expected = Date.diff(t1, t2) * @millis_per_day

        assert AvrogenTime.diff_millis(t1, t2) == expected
      end
    end

    property "matches NaiveDateTime.diff/3" do
      check all(
              t1 <- naive_datetime_generator(),
              t2 <- naive_datetime_generator()
            ) do
        assert AvrogenTime.diff_millis(t1, t2) ==
                 NaiveDateTime.diff(t1, t2, :millisecond)
      end
    end

    property "matches DateTime.diff/3" do
      check all(
              t1 <- datetime_generator(),
              t2 <- datetime_generator()
            ) do
        assert AvrogenTime.diff_millis(t1, t2) ==
                 DateTime.diff(t1, t2, :millisecond)
      end
    end

    property "matches Date tuple semantics" do
      check all(
              t1 <- date_tuple_generator(),
              t2 <- date_tuple_generator()
            ) do
        expected =
          Date.diff(
            Date.from_erl!(t1),
            Date.from_erl!(t2)
          ) * @millis_per_day

        assert AvrogenTime.diff_millis(t1, t2) == expected
      end
    end

    property "matches datetime tuple semantics" do
      check all(
              t1 <- datetime_tuple_generator(),
              t2 <- datetime_tuple_generator()
            ) do
        expected =
          NaiveDateTime.diff(
            NaiveDateTime.from_erl!(t1),
            NaiveDateTime.from_erl!(t2),
            :millisecond
          )

        assert AvrogenTime.diff_millis(t1, t2) == expected
      end
    end
  end

  #
  # add_millis/2
  #

  describe "add_millis/2" do
    property "adds milliseconds to Time" do
      check all(
              time <- time_generator(),
              millis <- integer(-10_000_000_000..10_000_000_000)
            ) do
        expected = Time.add(time, millis, :millisecond)

        assert AvrogenTime.add_millis(time, millis) == expected
      end
    end

    property "adds milliseconds to Date" do
      check all(
              date <- date_generator(),
              millis <- integer(-10_000_000_000..10_000_000_000)
            ) do
        seconds = div(millis, @millis_per_second)

        expected =
          if abs(seconds) < @seconds_per_day do
            date
          else
            days = div(seconds, @seconds_per_day)

            days =
              if seconds < 0 and rem(seconds, @seconds_per_day) != 0 do
                days - 1
              else
                days
              end

            Date.add(date, days)
          end

        assert AvrogenTime.add_millis(date, millis) == expected
      end
    end

    property "adds milliseconds to DateTime" do
      check all(
              datetime <- datetime_generator(),
              millis <- integer(-10_000_000_000..10_000_000_000)
            ) do
        expected = DateTime.add(datetime, millis, :millisecond)
        actual = AvrogenTime.add_millis(datetime, millis)

        assert DateTime.compare(actual, expected) == :eq
      end
    end

    property "adds milliseconds to NaiveDateTime" do
      check all(
              datetime <- naive_datetime_generator(),
              millis <- integer(-10_000_000_000..10_000_000_000)
            ) do
        expected = NaiveDateTime.add(datetime, millis, :millisecond)
        actual = AvrogenTime.add_millis(datetime, millis)

        assert NaiveDateTime.compare(actual, expected) == :eq
      end
    end

    test "Date ignores sub-day values" do
      date = ~D[2000-01-01]

      assert AvrogenTime.add_millis(date, -@millis_per_day + 1) == date
      assert AvrogenTime.add_millis(date, -1) == date
      assert AvrogenTime.add_millis(date, 0) == date
      assert AvrogenTime.add_millis(date, 1) == date
      assert AvrogenTime.add_millis(date, @millis_per_day - 1) == date
    end

    test "Date shifts at exact day boundaries" do
      date = ~D[2000-01-01]

      assert AvrogenTime.add_millis(date, @millis_per_day) ==
               ~D[2000-01-02]

      assert AvrogenTime.add_millis(date, -@millis_per_day) ==
               ~D[1999-12-31]
    end

    test "Date handles negative values immediately beyond day boundaries" do
      date = ~D[2000-01-01]

      assert AvrogenTime.add_millis(date, -@millis_per_day - 1) ==
               ~D[1999-12-31]

      assert AvrogenTime.add_millis(date, -@millis_per_day - 1_000) ==
               ~D[1999-12-30]
    end

    property "adds milliseconds to Date tuples" do
      check all(
              date <- date_tuple_generator(),
              millis <- integer(-10_000_000_000..10_000_000_000)
            ) do
        actual = AvrogenTime.add_millis(date, millis)

        {year, month, day} = date

        expected =
          {{year, month, day}, {0, 0, 0}}
          |> erl_datetime_add_millis(millis)
          |> elem(0)

        assert actual == expected
      end
    end

    property "adds milliseconds to datetime tuples" do
      check all(
              datetime <- datetime_tuple_generator(),
              millis <- integer(-10_000_000_000..10_000_000_000)
            ) do
        expected = erl_datetime_add_millis(datetime, millis)
        actual = AvrogenTime.add_millis(datetime, millis)

        assert actual == expected
      end
    end
  end

  defp erl_datetime_add_millis(datetime, millis) do
    seconds = div(millis, @millis_per_second)
    remainder_millis = rem(millis, @millis_per_second)

    seconds =
      if abs(seconds) >= @seconds_per_day do
        0
      else
        seconds
      end

    datetime
    |> NaiveDateTime.from_erl!()
    |> NaiveDateTime.add(seconds, :second)
    |> NaiveDateTime.add(remainder_millis, :millisecond)
    |> NaiveDateTime.to_erl()
  end
end
