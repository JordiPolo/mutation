defmodule CodeUtils do
  def count_nodes(code, element_name) do
    fn x -> x end # Do not modify anything
    |> create_transverse_function(element_name, -1)
    |> transverse_code(code)
    |> elem(1)
  end

  def mutate_element(code, element_name, element_position, modification_function) do
    modification_function
    |> create_transverse_function(element_name, element_position)
    |> transverse_code(code)
    |> elem(0)
  end

  def run_on_each_element(code, element_name, function, function_reason) do
#    IO.puts "New mutation #{element_name}"
    number_elements = CodeUtils.count_nodes(code, element_name)
#    IO.puts "Found #{number_elements}"

    if number_elements > 0 do
      Enum.map 1..number_elements, fn node_position ->
        { mutate_element(code, element_name, node_position, function), function_reason }
      end
    else
      []
    end
  end

  def evaluate_code(code) do
    ExUnit.CaptureIO.capture_io(:stderr, fn -> Code.eval_quoted(code) end)
  end

  def diff_code(original_code, mutated_code) do
    original_list = original_code
      |> Macro.to_string
      |> String.split("\n")
    mutated_list = mutated_code
      |> Macro.to_string
      |> String.split("\n")
    mutated_added = Enum.at(mutated_list -- original_list, 0)
    original_added = Enum.at(original_list -- mutated_list, 0)
    "+#{IO.ANSI.format([:green, mutated_added], true)}\n-#{IO.ANSI.format([:red, original_added], true)}"
  end

  defp create_transverse_function(modification_function, element_name, element_position) do
    fn
      # To debug:
      #      {element, meta, children}, context
      #        -> IO.puts ""; IO.inspect {element, children}; { {element, meta, children}, context}

      # Ignore lines with "when". We do not want to change the logic that defines the function itself.
      {:when, meta, children}, %{position: position, ignore_line: _}
        ->  {{:when, meta, children}, %{position: position, ignore_line: meta}}

      # Count the element when found
      {^element_name, meta, children}, %{position: position, ignore_line: ignore_line}
        when position != element_position and ignore_line != meta
        -> {{element_name, meta, children}, %{position: position + 1, ignore_line: ignore_line}}

      # Execute the given function when the element is in the right position
      {^element_name, meta, children}, %{position: position, ignore_line: ignore_line}
        when position == element_position and ignore_line != meta
        -> {modification_function.({element_name, meta, children}), %{position: position + 1, ignore_line: ignore_line}}

      # Keep the rest of the quotation unchanged.
      node, context
        ->  {node, context}
    end

  end

  defp transverse_code(transverse_function, code) do
    {quoted_code, %{position: position} } = Macro.prewalk(code, %{position: 1, ignore_line: -1}, transverse_function)
    {quoted_code, position - 1}
  end
end


defmodule Mutation do
  def find_all_mutants(quoted_code) do
    per_mutation = fn(element_name, mutation_function, mutation_reason)
      -> CodeUtils.run_on_each_element(quoted_code, element_name, mutation_function, mutation_reason)
    end
    all_mutants = Mutation.Mutations.each_mutation(per_mutation)
    IO.puts "Mutations found: #{Enum.count all_mutants}"
    [quoted_code | all_mutants]
  end

  def run_tests(tests) do
    # I need to run this every time or mutants are not killed
    ExUnit.CaptureIO.capture_io(:stderr, fn -> Kernel.ParallelCompiler.files(tests) end)

    time = ExUnit.Server.cases_loaded()
    %{failures: failures} =  ExUnit.Runner.run(ExUnit.configuration, time)
    if failures >= 1 do
      IO.write IO.ANSI.format([:green, :bright, "."], true)
      :fail
    else
      :ok
    end

  end

  def run_tests_on_mutants([original_code | mutants], tests) do
    total_failures = Enum.reduce(mutants, 0, fn {mutant, reason}, acc ->
       CodeUtils.evaluate_code(mutant)
       if run_tests(tests) == :ok do #test passed => mutation failed
         IO.puts ""
         IO.puts IO.ANSI.format([:red, :bright, "Failed mutation"], true)
         IO.puts CodeUtils.diff_code(original_code, mutant)
         IO.puts reason
         acc
       else
      #   IO.puts ""
      #   IO.puts IO.ANSI.format([:green, :bright, "Not failed mutation"], true)
      #   IO.puts CodeUtils.diff_code(original_code, mutant)
         acc + 1
       end
    end)

    if total_failures == Enum.count(mutants) do
      IO.write IO.ANSI.format([:green, :bright, "Passed "], true)
      IO.puts "ALL mutants killed! #{total_failures}/#{Enum.count(mutants)} killed."
    else
      IO.write IO.ANSI.format([:red, :bright, "Failed "], true)
      IO.puts "Expected #{Enum.count(mutants)} killed but only #{total_failures} were killed"
    end
  end

end

defmodule Mix.Tasks.Mutation do
  use Mix.Task

  @shortdoc "Runs all the mutations on your code and your tests."
  def run(directory \\ "./") do
    Mix.env(:test)
    ExUnit.start([autorun: false, verbose: true, formatters: [Mutation.TestFormatter]])

    test_files = Path.wildcard(Path.join(directory, "/test/**/*_test.exs"))
    code_files = Path.wildcard(Path.join(directory, "/lib/**/*.ex"))

    if File.exists?(Path.join(directory, "/test/test_helper.ex")) do
      Code.require_file Path.join(directory, "/test/test_helper.ex")
    end
    Kernel.ParallelRequire.files(code_files)
#    Kernel.ParallelRequire.files(test_files)

    IO.puts "Running mutations for #{directory}"
    IO.puts "Discovered code files #{code_files}"

    if Mutation.run_tests(test_files) == :fail do
      IO.puts "Running unmodified tests has failed. Make sure 'mix test' passes before performing any mutations."
    else
      IO.puts "All tests pass, proceding to create mutations."
      Enum.map(code_files, fn code_file ->
        code_file
        |> File.read!
        |> Code.string_to_quoted
        |> Mutation.find_all_mutants
        |> Mutation.run_tests_on_mutants(test_files)
      end)
    end

  end

end
