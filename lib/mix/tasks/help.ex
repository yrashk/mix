defmodule Mix.Tasks.Help do
  use Mix.Task
  @shortdoc "Print help information for tasks."
  @moduledoc """
  If given a task name, prints the documentation for that task.
  If no task name is given, prints the short form documentation
  for all tasks.

  Arguments:
    task: Print the @doc documentation for this task.
    none: Print the short form documentation for all tasks.
  """
  def run([]) do
    IO.puts "Available tasks:\n"
    modules = Mix.Tasks.list_tasks
    docs = lc module in modules do
      {module, module.__info__(:data)[:shortdoc]}
    end
    Enum.each(docs, fn({module, doc}) ->
      task = Mix.Tasks.module_to_task(module)
      if doc do
        IO.puts(task <> ": " <> doc)
      else
        IO.puts(task <> ": " <> "run `mix help " <>
                task <> "` to see documentation.")
      end
    end)
  end

  def run([task]) do
    case Mix.Tasks.get_module(task) do
    {:module, module} ->
      docs = module.__info__(:moduledoc)
      case docs do
      {_, docs} ->
        IO.puts docs
      else
        IO.puts "There is no documentation for this task."
      end
    {:error, _} ->
      IO.puts "No task by that name was found."
    end
  end
end
