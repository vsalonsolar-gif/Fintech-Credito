defmodule CreditSystemWeb.PageController do
  use CreditSystemWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
