require 'securerandom'
require 'opentelemetry/sdk'
require 'temporalio/activity'
require 'temporalio/client'
require 'temporalio/contrib/open_telemetry'
require 'temporalio/worker'
require 'temporalio/workflow'

OpenTelemetry::SDK.configure do |c|
  c.service_name = 'temporal-ruby-otel'
  c.use_all()
end

module TemporalRubyOtel
  Tracer = OpenTelemetry.tracer_provider.tracer('temporal-ruby')

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

  def client(server: 'localhost:7233', namespace: 'default', tracer: Tracer)
    Temporalio::Client.connect(
      server,
      namespace,
      interceptors: [Temporalio::Contrib::OpenTelemetry::TracingInterceptor.new(tracer)]
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
