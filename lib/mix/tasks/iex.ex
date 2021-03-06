defmodule Mix.Tasks.Iex do
  use Mix.Task
  @shortdoc "Start iex with your project's settings."
  @moduledoc """
  Starts an iex repl with your project settings.
  Your code will be available to iex because mix
  will add your `compile_path` and `erlang_compile_path`.
  Will compile first.
  """
  def run(_) do
    Mix.Tasks.run_task "compile"
    Elixir.IEx.start
    :timer.sleep(:infinity)
  end
end
