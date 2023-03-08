defmodule Avrogen.Util.Random do
  @moduledoc """
  Helper functions for generating random values.
  """

  @type rand_state() :: :rand.state() | :rand.export_state()

  @doc """
  Creates an infinite stream of random avro instances for a given generated
  avro record module. Useful for 'fuzz-testing' anything that processes avro
  data: push large numbers of random instances through the code and see if
  anything raises an exception.

  Each element in the stream is a tuple {rand_state, instance}, where
  rand_state is the random number generator state that was used to create the
  instance.  Feeding this rand_state into the AvroRecordModule's
  random_instance function will re-create the instance.
  """
  @spec stream(atom()) :: Enumerable.t()
  def stream(module) do
    stream(module, init_rand_state())
  end

  @doc """
  Creates a random stream with a particular starting rand_state, so an entire
  stream can be replayed just from the seed.
  """
  @spec stream(atom(), rand_state()) :: Enumerable.t()
  def stream(module, rand_state) do
    Stream.resource(
      fn -> init_rand_state(rand_state) end,
      fn rand_state ->
        {updated_rand_state, val} = module.random_instance(rand_state)
        {[{export_rand_state(rand_state), val}], updated_rand_state}
      end,
      fn _ -> :ok end
    )
  end

  @doc """
  Creates a fresh rand_state.
  """
  @spec init_rand_state() :: rand_state()
  def init_rand_state() do
    :rand.seed(:default)
  end

  @doc """
  Recreates a particular rand_state from the output of export_rand_state/1.
  """
  @spec init_rand_state(rand_state()) :: rand_state()
  def init_rand_state(rand_state) do
    :rand.seed_s(rand_state)
  end

  @doc """
  Exports the rand_state in a simple form that can be passed into
  init_rand_state/1.
  """
  @spec export_rand_state(rand_state()) :: rand_state()
  def export_rand_state(rand_state) do
    :rand.export_seed_s(rand_state)
  end

  @doc """
  Returns a tuple {new_rand_state, b}, where b is a random boolean.
  """
  def boolean(rand_state) do
    {f, s} = :rand.uniform_s(rand_state)

    b =
      if f >= 0.5 do
        true
      else
        false
      end

    {s, b}
  end

  @doc """
  Returns a tuple {new_rand_state, i}, where min <= i < max.
  """
  def integer(rand_state, min, max) when is_integer(min) and is_integer(max) and min < max do
    range = max - min - 1
    {f, s} = :rand.uniform_s(rand_state)
    {s, round(range * f) + min}
  end

  @doc """
  Returns a tuple {new_rand_state, f}, where f is a float with min <= f < max.
  """
  def float(rand_state, min, max) do
    range = max - min - 1
    {f, s} = :rand.uniform_s(rand_state)
    {s, range * f + min}
  end

  @doc """
  Returns a tuple {new_rand_state, d}, where d is a decimal with min <= d <
  max.
  """
  def decimal(rand_state, min, max) do
    range = max - min - 1
    {f, s} = :rand.uniform_s(rand_state)
    {s, Decimal.from_float(range * f + min)}
  end

  defp unicode_codepoint(rand_state, min, max) do
    integer(rand_state, min, max)
  end

  # 1114111 is the max unicode code point; unfortunately, there are unassigned code points in that range...
  #
  def string(rand_state, max_length \\ 1000, min_codepoint \\ 0, max_codepoint \\ 10_000) do
    {s, l} = integer(rand_state, 0, max_length)

    case l do
      0 ->
        {s, ""}

      _ ->
        {final_rand_state, unicode_chars} =
          Enum.reduce(1..l, {s, []}, fn _, {s, acc} ->
            {s2, u} = unicode_codepoint(s, min_codepoint, max_codepoint)
            {s2, [u | acc]}
          end)

        {final_rand_state, List.to_string(unicode_chars)}
    end
  end

  @uk_areas [
    "AB",
    "AL",
    "B",
    "BA",
    "BB",
    "BD",
    "BH",
    "BL",
    "BN",
    "BR",
    "BS",
    "BT",
    "CA",
    "CB",
    "CF",
    "CH",
    "CM",
    "CO",
    "CR",
    "CT",
    "CV",
    "CW",
    "DA",
    "DD",
    "DE",
    "DG",
    "DH",
    "DL",
    "DN",
    "DT",
    "DY",
    "E",
    "EC",
    "EH",
    "EN",
    "EX",
    "FK",
    "FY",
    "G",
    "GL",
    "GU",
    "GY",
    "HA",
    "HD",
    "HG",
    "HP",
    "HR",
    "HS",
    "HU",
    "HX",
    "IG",
    "IM",
    "IP",
    "IV",
    "JE",
    "KA",
    "KT",
    "KW",
    "KY",
    "L",
    "LA",
    "LD",
    "LE",
    "LL",
    "LN",
    "LS",
    "LU",
    "M",
    "ME",
    "MK",
    "ML",
    "N",
    "NE",
    "NG",
    "NN",
    "NP",
    "NR",
    "NW",
    "OL",
    "OX",
    "PA",
    "PE",
    "PH",
    "PL",
    "PO",
    "PR",
    "RG",
    "RH",
    "RM",
    "S",
    "SA",
    "SE",
    "SG",
    "SK",
    "SL",
    "SM",
    "SN",
    "SO",
    "SP",
    "SR",
    "SS",
    "ST",
    "SW",
    "SY",
    "TA",
    "TD",
    "TF",
    "TN",
    "TQ",
    "TR",
    "TS",
    "TW",
    "UB",
    "W",
    "WA",
    "WC",
    "WD",
    "WF",
    "WN",
    "WR",
    "WS",
    "WV",
    "YO",
    "ZE"
  ]
  @uk_unit [
    "A",
    "B",
    "D",
    "E",
    "F",
    "G",
    "H",
    "J",
    "L",
    "N",
    "P",
    "Q",
    "R",
    "S",
    "T",
    "U",
    "V",
    "W",
    "X",
    "Y",
    "Z"
  ]
  def postcode(rand_state) do
    {s, area} = list_element(rand_state, @uk_areas)
    {s, district} = integer(s, 1, 100)
    {s, sector} = integer(s, 1, 10)
    {s, unit_1} = list_element(s, @uk_unit)
    {s, unit_2} = list_element(s, @uk_unit)
    {s, "#{area}#{district} #{sector}#{unit_1}#{unit_2}"}
  end

  def list_element(rand_state, list) do
    {s, i} = integer(rand_state, 0, length(list))
    {s, Enum.at(list, i)}
  end

  @doc """
  Returns updated rand_state and random date between given start and end date.
  """
  def date(rand_state, start_date, end_date) do
    datetime(rand_state, start_date, end_date)
  end

  @doc """
  Picks a random date/datetime d such that start_date <= d < end_date. Returns
  {new_rand_state, d}.
  """
  def datetime(rand_state, start_date, end_date) do
    {end_d, start_d} =
      case Timex.compare(end_date, start_date) do
        -1 -> {start_date, end_date}
        _ -> {end_date, start_date}
      end

    range = abs(Timex.diff(end_d, start_d, :milliseconds))
    {s, millis} = integer(rand_state, 0, range)

    d = Timex.add(start_d, Timex.Duration.from_milliseconds(millis))
    {s, d}
  end

  defmodule Constructors do
    @doc """
    Provides functions that return "constructor functions". A constructor
    function is a function that expects a rand_state and optional parameters,
    and, on invocation, returns an updated rand_state and a randomly generated
    value.

    The functions in this module are basically 'lazy' wrappers around eager
    functions in the parent module.

    Thanks to this 'laziness', we can specify lists of alternative constructor
    functions, from which we can randomly choose an element for evaluation
    (without forcing all elements to be evaluated up front).
    """

    alias Avrogen.Util.Random
    @type constructor_fun() :: (Random.rand_state() -> {Random.rand_state(), any()})

    @spec nothing() :: constructor_fun()
    def nothing(), do: fn rand_state -> {rand_state, nil} end

    @spec boolean() :: constructor_fun()
    def boolean() do
      fn rand_state -> Random.boolean(rand_state) end
    end

    @spec integer(Keyword.t()) :: constructor_fun()
    def integer(opts \\ []) do
      min = Keyword.get(opts, :min, -2_147_483_648)
      max = Keyword.get(opts, :max, 2_147_483_648)
      fn rand_state -> Random.integer(rand_state, min, max) end
    end

    @spec float(Keyword.t()) :: constructor_fun()
    def float(opts \\ []) do
      min = Keyword.get(opts, :min, -2_147_483_648)
      max = Keyword.get(opts, :max, 2_147_483_648)
      fn rand_state -> Random.float(rand_state, min, max) end
    end

    @spec decimal(Keyword.t()) :: constructor_fun()
    def decimal(opts \\ []) do
      min = Keyword.get(opts, :min, -2_147_483_648)
      max = Keyword.get(opts, :max, 2_147_483_648)
      fn rand_state -> Random.decimal(rand_state, min, max) end
    end

    @spec string(Keyword.t()) :: constructor_fun()
    def string(opts \\ []) do
      case Keyword.get(opts, :semantic_type, nil) do
        "postcode" ->
          fn rand_state -> Random.postcode(rand_state) end

        _ ->
          max_length = Keyword.get(opts, :max_length, 64)
          min_codepoint = Keyword.get(opts, :min_codepoint, 20)
          max_codepoint = Keyword.get(opts, :max_codepoint, 127)
          fn rand_state -> Random.string(rand_state, max_length, min_codepoint, max_codepoint) end
      end
    end

    def map(value_constructor, opts \\ []) do
      max_length = Keyword.get(opts, :max_map_length, 10)
      key_constructor = string(opts)

      fn rand_state ->
        {rand_state, length} = Random.integer(rand_state, 0, max_length)

        Enum.reduce(0..length, {rand_state, %{}}, fn _, {rand_state, acc} ->
          {rand_state, key} = key_constructor.(rand_state)
          {rand_state, value} = value_constructor.(rand_state)
          {rand_state, Map.put(acc, key, value)}
        end)
      end
    end

    @spec enum_value(atom()) :: constructor_fun()
    def enum_value(enum_module) do
      fn rand_state ->
        values = Enum.to_list(enum_module.values())
        Random.list_element(rand_state, values)
      end
    end

    @spec date(Keyword.t()) :: constructor_fun()
    def date(opts \\ []) do
      min_date = Keyword.get(opts, :min_date, ~D[1970-01-01])
      max_date = Keyword.get(opts, :max_date, ~D[2045-01-21])

      fn rand_state ->
        Random.date(rand_state, min_date, max_date)
      end
    end

    @spec datetime(Keyword.t()) :: constructor_fun()
    def datetime(opts \\ []) do
      min_datetime = Keyword.get(opts, :min_date, ~U[1970-01-01 12:00:00.000000Z])
      max_datetime = Keyword.get(opts, :max_date, ~U[2045-01-01 12:00:00.000000Z])

      fn rand_state ->
        Random.datetime(rand_state, min_datetime, max_datetime)
      end
    end

    @spec list(constructor_fun(), integer()) :: constructor_fun()
    def list(constructor_fun, max_length \\ 10) do
      fn rand_state ->
        {updated_rand_state, n} = Random.integer(rand_state, 0, max_length + 1)

        if n == 0 do
          {updated_rand_state, []}
        else
          Enum.reduce(1..n, {updated_rand_state, []}, fn _, {rs, acc} ->
            {urs, value} = constructor_fun.(rs)
            {urs, [value | acc]}
          end)
        end
      end
    end

    @type constructor_list() :: {atom(), constructor_fun()} | {atom(), [constructor_fun]}
    # @spec instantiate(Random.rand_state(), module() | struct(), constructor_list()) ::
    #       {Random.rand_state(), struct()} -- not sure where the issue is...
    @spec instantiate(Random.rand_state(), module() | struct(), maybe_improper_list()) ::
            {Random.rand_state(), struct()}
    @doc """
    Instantiates a struct with random values as per the given constructors
    list. Returns the updated rand_state and the instantiated struct.
    """
    def instantiate(rand_state, struct_name, constructors) when is_list(constructors) do
      {final_rand_state, instantiations} =
        Enum.reduce(
          constructors,
          {rand_state, []},
          fn
            {key, constructor_fun_or_funs}, {rand_state, instantiations} ->
              {updated_rand_state, constructor_fun} = pick(rand_state, constructor_fun_or_funs)
              {updated_rand_state, value} = constructor_fun.(updated_rand_state)
              {updated_rand_state, [{key, value} | instantiations]}
          end
        )

      {final_rand_state, struct(struct_name, instantiations)}
    end

    defp pick(rand_state, constructor_fun) when is_function(constructor_fun),
      do: {rand_state, constructor_fun}

    defp pick(rand_state, constructor_funs) when is_list(constructor_funs) do
      {updated_rand_state, index} = Random.integer(rand_state, 0, length(constructor_funs))
      {updated_rand_state, Enum.at(constructor_funs, index)}
    end
  end
end
