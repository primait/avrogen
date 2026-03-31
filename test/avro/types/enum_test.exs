defmodule Avro.Types.EnumTest do
  use ExUnit.Case, async: true

  alias Avrogen.Avro.Schema

  test "should fail to decode a message with invalid enum value" do
    schema = """
    {
    "name": "TestEnumRecord",
    "type": "record",
    "fields": [
     {
        "name": "monthly_payment_plan_identifier",
        "doc": "The monthly payment plan available for this offer.",
        "default": null,
        "type": [
          "null",
          {
            "name": "MonthlyPaymentPlanIdentifier",
            "type": "enum",
            "symbols": [
              "CB2010",
              "CB0911"
            ]
          }
        ]
      }
    ]
    }

    """

    module =
      schema
      |> generate_code()
      |> Enum.map(&compile_code/1)
      |> Enum.map(&module_name/1)
      |> Enum.reject(&is_nil/1)
      |> List.first()

    instance = struct(module, monthly_payment_plan_identifier: :CB2010)

    assert {:error, _} =
             instance
             |> module.to_avro_map()
             |> Map.put("monthly_payment_plan_identifier", "SomethingElse")
             |> module.from_avro_map()
  end

  defp generate_code(schema) do
    schema
    |> Jason.decode!()
    |> Schema.generate_code([], "Test")
    |> Enum.map(&elem(&1, 1))
  end

  defp compile_code(code) do
    code
    |> IO.iodata_to_binary()
    |> Code.compile_string()
  end

  # Gets the module name of the record type generated code
  defp module_name([_, {mod_name, _}]), do: mod_name
  defp module_name(_), do: nil
end
