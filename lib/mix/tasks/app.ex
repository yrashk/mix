defmodule Mix.Tasks.App do
   use Mix.Task
   @shortdoc "Writes an .app file"
   refer List.Chars, as: LC
   def run(_args) do
       project = Mix.Mixfile.get_project
       app_name_atom = list_to_atom(LC.to_char_list project[:project])
       app_name = LC.to_char_list app_name_atom
       compile_path = project[:compile_path]
       modules = 
       lc file in File.wildcard("#{compile_path}/**/*.beam") do
          s = Regex.replace_all(%r/\//, Regex.replace(%r/ebin\/__MAIN__\/(.+)\.beam/, file, "\\1"), ".")
          Module.concat [s]
       end

       best_guess_app = [vsn: (LC.to_char_list project[:version]), modules: modules]
       app = {:application, app_name_atom, Keyword.merge best_guess_app, Mix.Project.application}

       # write down the .app file
       {:ok, f} = :file.open(File.join([compile_path, "#{app_name}.app"]),[:write])
       :io.fwrite(f, "~p.", [app])
       :file.close(f)
   end
end