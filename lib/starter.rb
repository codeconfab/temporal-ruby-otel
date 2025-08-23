require 'app'

TemporalRubyOtel::Tracer.in_span('cli:DemoWorkflows') do
  result1 = TemporalRubyOtel.execute_workflow(
    workflow: :say_hello,
    args: 'Arthur Dent',
  )

  result2 = TemporalRubyOtel.execute_workflow(
    workflow: :say_hello,
    args: "Ford Prefect! #{result1}",
  )

  puts result1, result2
end
