defmodule Mutation.TestFormatter do
  @moduledoc """
    A simple formatter with very clean output to use for the output of the tests run on mutations.
  """
  use GenServer

  def init(_) do
   {:ok, nil}
  end

  # TODO: Why is this called here but not in https://github.com/elixir-lang/elixir/blob/master/lib/ex_unit/lib/ex_unit/cli_formatter.ex
  def handle_event(x, y) do
    {:ok, :continue}
  end

  def handle_cast(_, x) do
    {:noreply, x}
  end
end
