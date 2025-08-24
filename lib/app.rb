require 'securerandom'
require 'opentelemetry/sdk'
require 'opentelemetry/exporter/otlp'
require 'temporalio/activity'
require 'temporalio/client'
require 'temporalio/contrib/open_telemetry'
require 'temporalio/worker'
require 'temporalio/workflow'

case ENV['TRACE_BACKEND']
when 'console'
  ENV['OTEL_TRACES_EXPORTER'] = 'console'
when 'honeycomb'
  api_key = ENV.fetch('HONEYCOMB_API_KEY') do |key|
    raise KeyError, "key not found in ENV: #{key}. Add it to .env or provide it using your preferred method."
  end

  ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'https://api.honeycomb.io'
  ENV['OTEL_EXPORTER_OTLP_HEADERS'] = "x-honeycomb-team=#{api_key}"
end

OpenTelemetry::SDK.configure do |c|
  c.service_name = 'temporal-ruby-otel'
  c.use_all()
  at_exit { OpenTelemetry.tracer_provider.shutdown }
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

  def execute_workflow(client: self.client, workflow:, args:, task_queue: TASK_QUEUE_NAME, id: "wf-#{SecureRandom.uuid}")
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
