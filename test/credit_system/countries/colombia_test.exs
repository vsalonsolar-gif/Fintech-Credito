defmodule CreditSystem.Countries.ColombiaTest do
  use ExUnit.Case, async: true

  alias CreditSystem.Countries.Colombia

  describe "validate_document/1" do
    test "accepts valid CC - 10 digits" do
      assert {:ok, "1020345678"} = Colombia.validate_document("1020345678")
    end

    test "accepts valid CC - 6 digits" do
      assert {:ok, "123456"} = Colombia.validate_document("123456")
    end

    test "rejects CC with letters" do
      assert {:error, _} = Colombia.validate_document("ABC123")
    end

    test "rejects CC too short" do
      assert {:error, _} = Colombia.validate_document("12345")
    end

    test "rejects CC too long" do
      assert {:error, _} = Colombia.validate_document("12345678901")
    end
  end

  describe "validate_application/1" do
    test "approves valid application" do
      attrs = %{
        "requested_amount" => "50000000",
        "monthly_income" => "8000000",
        "banking_info" => %{"total_debt" => "2000000"}
      }

      assert {:ok, _} = Colombia.validate_application(attrs)
    end

    test "rejects when amount exceeds max" do
      attrs = %{
        "requested_amount" => "250000000",
        "monthly_income" => "50000000",
        "banking_info" => %{"total_debt" => "1000000"}
      }

      assert {:error, errors} = Colombia.validate_application(attrs)
      assert Enum.any?(errors, &String.contains?(&1, "200,000,000"))
    end

    test "rejects when debt-to-income ratio too high" do
      attrs = %{
        "requested_amount" => "50000000",
        "monthly_income" => "5000000",
        "banking_info" => %{"total_debt" => "3000000"}
      }

      assert {:error, errors} = Colombia.validate_application(attrs)
      assert Enum.any?(errors, &String.contains?(&1, "ratio"))
    end

    test "flags high amounts for additional review" do
      attrs = %{
        "requested_amount" => "150000000",
        "monthly_income" => "50000000",
        "banking_info" => %{"total_debt" => "1000000"}
      }

      assert {:ok, %{requires_additional_review: true}} = Colombia.validate_application(attrs)
    end
  end

  test "country_code/0 returns CO" do
    assert Colombia.country_code() == "CO"
  end

  test "document_type/0 returns CC" do
    assert Colombia.document_type() == "CC"
  end
end
