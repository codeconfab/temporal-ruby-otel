require 'app'

worker = TemporalRubyOtel.worker

worker.run(shutdown_signals: ['SIGINT'])
