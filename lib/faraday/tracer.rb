require 'faraday'
require 'opentracing'

module Faraday
  class Tracer < Faraday::Middleware
    def initialize(app, span: nil, tracer: OpenTracing.global_tracer)
      super(app)
      @tracer = tracer
      @parent_span = span
    end

    def call(env)
      span = @tracer.start_span(env[:method],
        child_of: @parent_span,
        tags: {
          'component' => 'faraday',
          'span.kind' => 'server',
          'http.method' => env[:method],
          'http.url' => env[:url].to_s
        }
      )
      @tracer.inject(span.context, OpenTracing::FORMAT_RACK, env[:request_headers])
      @app.call(env).on_complete do |response|
        span.set_tag('http.status_code', response.status)
        span.finish
      end
    end
  end
end
