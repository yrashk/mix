defmodule Mix.Task do
  def behaviour_info(:callbacks) do
    [run: 1]
  end

  defp property(name, options) do
     expr = 
     case options do
          [do: do_block] -> do_block
          value -> value
     end
     quote do
        def unquote(name).() do
            v = unquote(expr)
            super ++ v
        end
     end
  end

  defmacro provides(options) do
      property(:__provides__, options)
  end

  defmacro requires(options) do
      property(:__requires__, options)
  end

  # We may want to autoimport a util library in the future.
  defmacro __using__(mod, opts // []) do
    quote do
      @behavior unquote(__MODULE__)
      import Mix.Task

      def __provides__ do
          task = Mix.Tasks.module_to_task(__MODULE__)
          [task,
           binary_to_atom(task),
           __MODULE__]
      end

      def __requires__ do
          []
      end

      defoverridable [__provides__: 0, __requires__: 0]
   end
  end
end
