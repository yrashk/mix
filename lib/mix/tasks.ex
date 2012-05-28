defexception Mix.TaskError, [context: :mix, report: "Unknown error"] do
   def message(exception) do
        "Error in #{exception.context}: #{exception.report}"
   end
   
   def throw!(exception), do: throw(exception)
end

defmodule Mix.Tasks do
  @moduledoc """
  Utilities for finding tasks and returning them as modules.
  """

  @doc """
  List all of the tasks on the load path
  as their respective modules.
  """
  def list_tasks() do
    load_all_tasks
    Enum.reduce(:code.all_loaded, [], fn({module, _}, acc) ->
      proper = Regex.run(%r/Mix\.Tasks\..*/, atom_to_list(module))
      if proper && is_task?(module) do
        acc = [module|acc]
        acc
      else
        acc
      end
    end)
  end

  defp load_all_tasks() do
    Enum.each(:code.get_path, fn(x) ->
      files = File.wildcard(x ++ '/__MAIN__/Mix/Tasks/**/*.beam')
      Enum.each(files, fn(x) ->
        get_module(:filename.rootname(File.basename(x)))
      end)
    end)
  end

  @doc """
  Takes a raw task name (totally lower case) and
  tries to load that task's associated module.
  If the task does not exist or cannot be loaded,
  a tuple of {:error, what} is returned. If the
  task module is successfully loaded, a tuple of
  {:module, module} is returned.
  """
  def get_module(s) when is_atom(s), do: get_module atom_to_binary(s)
  def get_module(s) when is_list(s), do: get_module list_to_binary(s)
  def get_module(s) do
    name = Module.concat(Mix.Tasks, capitalize_task(s))
    :code.ensure_loaded(name)
  end

  @doc """
  Run a task with arguments. If no arguments are
  passed, an empty list is used.
  """
  def run_task(name, args // []) do
    case Mix.Tasks.get_module(name) do
    {:module, module} ->
      if is_task?(module) do
        try do
          run_dependencies(name, args)
        catch
          _, Mix.TaskError[] = report ->
             IO.puts report.message
        end
      else
        IO.puts "That task could not be found."
      end
    {:error, _} ->
      IO.puts "That task could not be found."
    end
  end

  refer :digraph, as: G

  refer :digraph_utils, as: GU


  # In order to resolve and run necessary dependencies, the following
  # algorithm builds a digraph where every vertex is either a task reference
  # or a target. It then maps values that are not tasks to tasks (using
  # Task.__provides__). In order to satisfy deoendencies in the right 
  # order, it selects all vertices with no emanating edges (which means
  # that those vertices do not have dependencies). Their respective
  # tasks are run (unless if the vertice is in fact describing a file)
  # and unlinked from all edges it is incident on, so that they don't
  # get included into further processing. Before proceeding further,
  # those vertices are linked to the :satisfaction vertex to log
  # their completion. This digraph gets processed until there are no
  # vertices with no emanating edges, which means there are no
  # unsatisfied dependencies anymore.

  defp run_dependencies(task, args) do
       g = G.new
       targets = resolve_dependencies(g, task)
       G.add_vertex(g, :satisfaction)
       run_resolved_tasks(g, targets, args)
       G.delete g
  end

  defp run_resolved_tasks(g, targets, args) do
       report = 
       lc task in G.vertices(g) when
          G.out_edges(g, task) == [] and
          task !== :satisfaction do
              module = Dict.get(targets, task)
              case module do
                  nil ->
                      # no mapping
                      # may be it is a file?
                      case File.exists?(task) do
                          true ->
                              lc edge in G.in_edges(g, task), do: G.del_edge(g, edge)
                               G.add_edge(g, task, :satisfaction)
                          false ->
                              Mix.TaskError.new(report:"Can't satisfy a requirement for #{task}").throw!
                      end
                  _ ->
                      try do
                          module.run(args) 
                      catch
                          _, Mix.TaskError[] = error ->
                              error.context("'#{task}' task").throw!()
                      end
                      lc edge in G.in_edges(g, task), do: G.del_edge(g, edge)
                      G.add_edge(g, task, :satisfaction)
              end
       end
       case report do
            [] -> :ok
            _ -> run_resolved_tasks(g, targets, args)
       end
  end

  defp resolve_dependencies(g, task) do
       {:module, module} = Mix.Tasks.get_module(task)
       G.add_vertex(g, task)
       reqs = module.__requires__ 
       lc req in reqs do
           G.add_vertex(g, req)
           G.add_edge(g, task, req)
       end
       lc req_task in (lc e in G.edges(g, task), do: ({_, _, t, _} = G.edge(g, e); t)) when requirement_is_task?(req_task) and req_task !== task  do
           resolve_dependencies(g, req_task)
           case GU.is_tree(g) do
               true -> :ok
               false ->
                   Mix.TaskError.new(report: "After adding #{req_task}, dependency graph is no longer a tree").throw!
           end
       end
       tasks = list_tasks
       HashDict.new(
       lc task in tasks, target in task.__provides__ do
           {target, task}
       end)
  end

  defp requirement_is_task?(name) do
     case Mix.Tasks.get_module(name) do
         {:module, module} ->
             is_task?(module)
         _ ->
             false
     end
  end


  @doc """
  Takes a module and extracts the last portion of it,
  lower-cases the first letter, and returns the name.
  """
  def module_to_task(module) do
    to_lower(List.last(Regex.split(%r/\./, list_to_binary(atom_to_list(module)), 4)))
  end

  @doc """
  Takes a task as a string like "foo" or "foo.bar"
  and capitalizes each segment to form a module name.
  """
  def capitalize_task(s) do
    Enum.join(Enum.map(Regex.split(%r/\./, s), Mix.Utils.capitalize(&1)), ".")
  end

  @doc """
  Find out if a module defines a :run function
  of one argument. This indicates whether or not
  it is a task as opposed to a module holding
  other namespaced tasks.
  """
  def is_task?(module) when is_atom(module) do
    Enum.find(module.module_info(:functions), fn({name, arity}) ->
      name == :run && arity == 1
    end) !== false
  end

  defp to_lower(task) do
    list_to_binary(:string.to_lower(binary_to_list task))
  end
end
