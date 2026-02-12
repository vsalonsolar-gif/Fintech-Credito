defmodule CreditSystem.Applications.StateMachine do
  @moduledoc """
  State machine for credit application status transitions.

  States:
  - pending: Initial state
  - validating: Document and rules validation in progress
  - under_review: Manual review required (high amounts)
  - approved: Application approved
  - rejected: Application rejected
  - disbursed: Funds disbursed
  """

  @transitions %{
    "pending" => ["validating", "rejected"],
    "validating" => ["under_review", "approved", "rejected"],
    "under_review" => ["approved", "rejected"],
    "approved" => ["disbursed", "rejected"],
    "rejected" => [],
    "disbursed" => []
  }

  @all_states Map.keys(@transitions)

  def valid_states, do: @all_states

  def valid_transition?(from, to) do
    to in Map.get(@transitions, from, [])
  end

  def available_transitions(status) do
    Map.get(@transitions, status, [])
  end

  def transition(application, new_status) do
    if valid_transition?(application.status, new_status) do
      {:ok, new_status}
    else
      {:error,
       "Transicion invalida de #{application.status} a #{new_status}. Disponibles: #{inspect(available_transitions(application.status))}"}
    end
  end
end
