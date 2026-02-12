defmodule CreditSystem.Countries.MexicoTest do
  use ExUnit.Case, async: true

  alias CreditSystem.Countries.Mexico

  describe "validate_document/1" do
    test "accepts valid CURP" do
      assert {:ok, "GALC900101HDFRRL09"} = Mexico.validate_document("GALC900101HDFRRL09")
    end

    test "rejects invalid CURP - too short" do
      assert {:error, _} = Mexico.validate_document("GALC900")
    end

    test "rejects invalid CURP - wrong format" do
      assert {:error, _} = Mexico.validate_document("12345678901234567A")
    end

    test "trims and uppercases input" do
      assert {:ok, "GALC900101HDFRRL09"} = Mexico.validate_document("  galc900101hdfrrl09  ")
    end
  end

  describe "validate_application/1" do
    test "approves valid application" do
      attrs = %{
        "requested_amount" => "100000",
        "monthly_income" => "50000"
      }

      assert {:ok, _meta} = Mexico.validate_application(attrs)
    end

    test "rejects when amount exceeds max" do
      attrs = %{
        "requested_amount" => "600000",
        "monthly_income" => "200000"
      }

      assert {:error, errors} = Mexico.validate_application(attrs)
      assert Enum.any?(errors, &String.contains?(&1, "500,000"))
    end

    test "rejects when income too low" do
      attrs = %{
        "requested_amount" => "120000",
        "monthly_income" => "10000"
      }

      assert {:error, errors} = Mexico.validate_application(attrs)
      assert Enum.any?(errors, &String.contains?(&1, "3x"))
    end

    test "flags high amounts for additional review" do
      attrs = %{
        "requested_amount" => "300000",
        "monthly_income" => "200000"
      }

      assert {:ok, %{requires_additional_review: true}} = Mexico.validate_application(attrs)
    end
  end

  test "country_code/0 returns MX" do
    assert Mexico.country_code() == "MX"
  end

  test "document_type/0 returns CURP" do
    assert Mexico.document_type() == "CURP"
  end
end
