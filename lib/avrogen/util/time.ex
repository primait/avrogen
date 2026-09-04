defmodule Avrogen.Util.Time do
  @moduledoc """
  Utilities for comparing, adding, and calculating differences between
  supported date and time representations.

  The module provides a small common interface over Elixir's `Time`, `Date`,
  `DateTime`, and `NaiveDateTime` types, as well as Erlang date and datetime
  tuples.

  The interface is intended to replace the subset of Timex functionality used
  by Avrogen:

    * `Timex.compare/2`
    * `Timex.diff/3` with `:milliseconds`
    * `Timex.add/2` with a duration created from milliseconds

  `compare/2` returns `:lt`, `:eq`, or `:gt` instead of Timex's `-1`, `0`, or
  `1`. The other operations preserve the behavior expected by existing
  callers.
  """

  @type year :: Calendar.year()
  @type month :: Calendar.month()
  @type day :: Calendar.day()
  @type date :: {year, month, day}

  @type hour :: Calendar.hour()
  @type minute :: Calendar.minute()
  @type second :: Calendar.second()
  @type time :: {hour, minute, second}

  @type datetime :: {date, time}

  @type t :: Time.t() | Date.t() | DateTime.t() | NaiveDateTime.t() | date | datetime

  @seconds_per_day 86_400
  @millis_per_second 1_000

  @spec compare(t1 :: t, t2 :: t) :: :lt | :eq | :gt
  def compare(%Time{} = t1, %Time{} = t2) do
    Time.compare(t1, t2)
  end

  def compare(%Date{} = t1, %Date{} = t2) do
    Date.compare(t1, t2)
  end

  def compare(%DateTime{} = t1, %DateTime{} = t2) do
    DateTime.compare(t1, t2)
  end

  def compare(%NaiveDateTime{} = t1, %NaiveDateTime{} = t2) do
    NaiveDateTime.compare(t1, t2)
  end

  def compare({_, _, _} = t1, {_, _, _} = t2) do
    t1
    |> Date.from_erl!()
    |> Date.compare(Date.from_erl!(t2))
  end

  def compare({{_, _, _}, {_, _, _}} = t1, {{_, _, _}, {_, _, _}} = t2) do
    t1
    |> NaiveDateTime.from_erl!()
    |> NaiveDateTime.compare(NaiveDateTime.from_erl!(t2))
  end

  @spec diff_millis(t1 :: t, t2 :: t) :: integer()
  def diff_millis(%Time{} = t1, %Time{} = t2) do
    Time.diff(t1, t2, :millisecond)
  end

  def diff_millis(%Date{} = t1, %Date{} = t2) do
    Date.diff(t1, t2) * 86_400_000
  end

  def diff_millis(%DateTime{} = t1, %DateTime{} = t2) do
    DateTime.diff(t1, t2, :millisecond)
  end

  def diff_millis(%NaiveDateTime{} = t1, %NaiveDateTime{} = t2) do
    NaiveDateTime.diff(t1, t2, :millisecond)
  end

  def diff_millis({_, _, _} = t1, {_, _, _} = t2) do
    Date.diff(Date.from_erl!(t1), Date.from_erl!(t2)) *
      @seconds_per_day *
      @millis_per_second
  end

  def diff_millis({{_, _, _}, {_, _, _}} = t1, {{_, _, _}, {_, _, _}} = t2) do
    NaiveDateTime.diff(
      NaiveDateTime.from_erl!(t1),
      NaiveDateTime.from_erl!(t2),
      :millisecond
    )
  end

  @spec add_millis(Time.t(), millisecond :: integer) :: Time.t()
  @spec add_millis(Date.t(), millisecond :: integer) :: Date.t()
  @spec add_millis(DateTime.t(), millisecond :: integer) :: DateTime.t()
  @spec add_millis(NaiveDateTime.t(), millisecond :: integer) :: NaiveDateTime.t()
  @spec add_millis(date, millisecond :: integer) :: date
  @spec add_millis(datetime, millisecond :: integer) :: datetime
  def add_millis(%Time{} = time, millis) do
    Time.add(time, millis, :millisecond)
  end

  def add_millis(%Date{} = date, millis) do
    seconds = div(millis, @millis_per_second)

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
  end

  def add_millis(%DateTime{} = datetime, millis) do
    DateTime.add(datetime, millis, :millisecond)
  end

  def add_millis(%NaiveDateTime{} = datetime, millis) do
    NaiveDateTime.add(datetime, millis, :millisecond)
  end

  def add_millis({year, month, day}, millis) do
    {{year, month, day}, {0, 0, 0}}
    |> add_millis_to_erl_datetime(millis)
    |> elem(0)
  end

  def add_millis(datetime, millis) when is_tuple(datetime) do
    add_millis_to_erl_datetime(datetime, millis)
  end

  defp add_millis_to_erl_datetime({{_, _, _}, {_, _, _}} = datetime, millis) do
    seconds = div(millis, @millis_per_second)
    milliseconds = rem(millis, @millis_per_second)

    datetime =
      NaiveDateTime.from_erl!(datetime)
      |> NaiveDateTime.add(
        if(abs(seconds) < @seconds_per_day, do: seconds, else: 0),
        :second
      )
      |> NaiveDateTime.add(milliseconds, :millisecond)

    NaiveDateTime.to_erl(datetime)
  end
end
