require 'securerandom'
require 'temporalio/activity'
require 'temporalio/client'
require 'temporalio/worker'
require 'temporalio/workflow'

module TemporalRubyOtel
  class SayHelloActivity < Temporalio::Activity::Definition
    def execute(name)
      "Hello, #{name}!"
    end
  end

  class SayHelloWorkflow < Temporalio::Workflow::Definition
    def execute(name)
      Temporalio::Workflow.execute_activity(
        SayHelloActivity,
        name,
        schedule_to_close_timeout: 300
      )
    end
  end

  TASK_QUEUE_NAME = "tq-temporal-ruby-otel"
  WORKFLOWS = {
    say_hello: SayHelloWorkflow,
  }

  extend self

  def client(server: 'localhost:7233', namespace: 'default')
    Temporalio::Client.connect(
      server,
      namespace,
    )
  end

  def execute_workflow(client:, workflow:, args:, task_queue: TASK_QUEUE_NAME, id: "wf-#{SecureRandom.uuid}")
    workflow_class = WORKFLOWS[workflow]

    client.execute_workflow(
      workflow_class,
      args,
      id: id,
      task_queue: task_queue,
    )
  end

  def worker(client = self.client)
    Temporalio::Worker.new(
      client:,
      task_queue: TASK_QUEUE_NAME,
      activities: [SayHelloActivity],
      workflows: [SayHelloWorkflow],
    )
  end
end
