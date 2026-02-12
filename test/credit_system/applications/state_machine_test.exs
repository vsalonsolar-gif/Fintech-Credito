defmodule CreditSystem.Applications.StateMachineTest do
  use ExUnit.Case, async: true

  alias CreditSystem.Applications.StateMachine

  describe "valid_transition?/2" do
    test "pending -> validating is valid" do
      assert StateMachine.valid_transition?("pending", "validating")
    end

    test "pending -> rejected is valid" do
      assert StateMachine.valid_transition?("pending", "rejected")
    end

    test "pending -> approved is invalid" do
      refute StateMachine.valid_transition?("pending", "approved")
    end

    test "validating -> approved is valid" do
      assert StateMachine.valid_transition?("validating", "approved")
    end

    test "validating -> under_review is valid" do
      assert StateMachine.valid_transition?("validating", "under_review")
    end

    test "approved -> disbursed is valid" do
      assert StateMachine.valid_transition?("approved", "disbursed")
    end

    test "rejected is terminal" do
      refute StateMachine.valid_transition?("rejected", "approved")
      refute StateMachine.valid_transition?("rejected", "pending")
    end

    test "disbursed is terminal" do
      refute StateMachine.valid_transition?("disbursed", "approved")
    end
  end

  describe "available_transitions/1" do
    test "pending has validating and rejected" do
      assert StateMachine.available_transitions("pending") == ["validating", "rejected"]
    end

    test "rejected has no transitions" do
      assert StateMachine.available_transitions("rejected") == []
    end
  end

  describe "transition/2" do
    test "valid transition returns ok" do
      app = %{status: "pending"}
      assert {:ok, "validating"} = StateMachine.transition(app, "validating")
    end

    test "invalid transition returns error" do
      app = %{status: "pending"}
      assert {:error, _reason} = StateMachine.transition(app, "approved")
    end
  end
end
