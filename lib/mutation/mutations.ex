defmodule Mutation.Mutations do

  # Transverses all the mutations
  def each_mutation(code_transverse_function) do
    Enum.flat_map all_mutations, fn(mutation_map) ->
      Enum.reduce mutation_map.functions, [], fn({mutation_function, mutation_reason}, acc) ->
        result = code_transverse_function.(mutation_map.tag, mutation_function, mutation_reason)
    #    For debug
    #    IO.inspect result
    #    IO.inspect mutation_reason
        Enum.concat(acc, result)
      end
    end
  end

  defp all_mutations do
    [
      %{
        tag: :>,
        functions: numeric_comparison_functions(:>)
      },
      %{
        tag: :>=,
        functions: numeric_comparison_functions(:>=)
      },
      %{
        tag: :<,
        functions: numeric_comparison_functions(:<)
      },
      %{
        tag: :<=,
        functions: numeric_comparison_functions(:<=)
      },
      %{
        tag: :==,
        functions: [
          {
            fn {:==, meta, [left, right]} -> {:!=, meta, [left, right]} end,
            "Write a test to check the result when this equality happens."
          }
        ]
      },
      %{
        tag: :!=,
        functions: [
          {
            fn {:!=, meta, [left, right]} -> {:==, meta, [left, right]} end,
            "Write a test to check the result when this inequality happens."
          }
        ]
      },
      %{
        tag: :and,
        functions: [
          {
            fn {:and, meta, [_cond1, cond2]} -> {:and, meta, [true, cond2]} end,
            "Write a test to check the result when the left side condition evaluates to false."
          },{
            fn {:and, meta, [_cond1, cond2]} -> {:and, meta, [false, cond2]} end,
            "Write a test to check the result when the left side condition evaluates to true."
          },{
            fn {:and, meta, [cond1, _cond2]} -> {:and, meta, [cond1, true]} end,
            "Write a test to check the result when the right side condition evaluates to false."
          },{
            fn {:and, meta, [cond1, _cond2]} -> {:and, meta, [cond1, false]} end,
            "Write a test to check the result when the right side condition evaluates to true."
          },{
            fn {:and, meta, [cond1, cond2]} -> {:or, meta, [cond1, cond2]} end,
            "Write a test to check the result when the left side and the right side conditions evaluate to true."
          }
        ]
      },
      %{
        tag: :or,
        functions: [
          {
            fn {:or, meta, [_cond1, cond2]} -> {:or, meta, [true, cond2]} end,
            "Write a test to check the result when the left side condition evaluates to false."
          },{
            fn {:or, meta, [_cond1, cond2]} -> {:or, meta, [false, cond2]} end,
            "Write a test to check the result when the left side condition evaluates to true."
          },{
            fn {:or, meta, [cond1, _cond2]} -> {:or, meta, [cond1, true]} end,
            "Write a test to check the result when the right side condition evaluates to false."
          },{
            fn {:or, meta, [cond1, _cond2]} -> {:or, meta, [cond1, false]} end,
            "Write a test to check the result when the right side condition evaluates to true."
          },{
            fn {:or, meta, [cond1, cond2]} -> {:and, meta, [cond1, cond2]} end,
            "Write a test to check the result when the left side and the right side conditions evaluate to true."
          }
        ]
      },
      %{
        tag: :if,
        functions: [
          {
            fn {:if, meta, [_cond_arg, code_arg]} -> {:if, meta, [true, code_arg]} end,
            "Write a test to check the result of making the condition of this `if` to evaluate to false."
          },{
            fn {:if, meta, [_cond_arg, code_arg]} -> {:if, meta, [false, code_arg]} end,
            "Write a test to check the result of making the condition of this `if` to evaluate to true"
          },{
          #  fn {:if, meta, [_cond_arg, code_arg]} -> {:if, meta, [nil, code_arg]} end,
            fn {:if, meta, [cond_arg, code_arg]} -> {:if, meta, [negate_conditional_node(meta, cond_arg), code_arg]} end,
            "Write a test to check the result of making the condition of this `if` to evaluate to true"
          }
        ]
      }
    ]
  end

  defp numeric_comparison_functions(element_name) do
    all_comparisons = %{
      <: {
        fn {^element_name, meta, [left, right]} -> {:<, meta, [left, right]} end,
        "Write a test to check the result when the left side is the same than the right"
      },
      <=: {
        fn {^element_name, meta, [left, right]} -> {:<=, meta, [left, right]} end,
        "Write a test to check the result when the left side is bigger than the right"
      },
      >: {
        fn {^element_name, meta, [left, right]} -> {:>, meta, [left, right]} end,
        "Write a test to check the result when the right side is the same than the left"
      },
       >=: {
        fn {^element_name, meta, [left, right]} -> {:>=, meta, [left, right]} end,
        "Write a test to check the result when the right side is bigger than the left"
      },
      ==: {
        fn {^element_name, meta, [left, right]} -> {:==, meta, [left, right]} end,
        "Write a test to check the result when the left side is a different value from the right"
      },
      !=: {
        fn {^element_name, meta, [left, right]} -> {:!=, meta, [left, right]} end,
        "Write a test to check the result when the left side is the same value than the right"
      }
    }
    all_comparisons
    |> Map.delete(element_name)
    |> Map.values
  end

  defp negate_conditional_node(meta, conditional_arg) do
    {:!, meta, [conditional_arg]}
  end
end
