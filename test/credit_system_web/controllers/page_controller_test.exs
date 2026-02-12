defmodule CreditSystemWeb.PageControllerTest do
  use CreditSystemWeb.ConnCase

  test "GET / renders the applications page", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Credit Applications"
  end
end
