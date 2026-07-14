require 'minitest/autorun'

require 'temporalio/testing'

require 'app'

class TemporalRubyOtelTest < Minitest::Test
  def test_say_hello_workflow
    Temporalio::Testing::WorkflowEnvironment.start_local do |env|
      worker = TemporalRubyOtel.worker(env.client)

      result = worker.run do
        result = TemporalRubyOtel.execute_workflow(
          client: env.client,
          workflow: :say_hello,
          args: 'some-name',
        )

      end

      sleep 0.1

      assert_equal 'Hello, some-name!', result
    end
  end
end
