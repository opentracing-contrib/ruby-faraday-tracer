require 'faraday'
require 'opentracing'

module Faraday
  class Tracer < Faraday::Middleware
    # Create a new Faraday Tracer middleware.
    #
    # @param app The faraday application/middlewares stack.
    # @param span [Span, SpanContext, Proc, nil] SpanContext that acts as a parent to
    #        the newly-started by the middleware Span. If a Proc is provided, its
    #        evaluated during the call method invocation.
    # @param tracer [OpenTracing::Tracer] A tracer to be used when start_span, and inject
    #        is called.
    # @param errors [Array<Class>] An array of error classes to be captured by the tracer
    #        as errors. Errors are **not** muted by the middleware.
    def initialize(app, span: nil, tracer: OpenTracing.global_tracer, errors: [StandardError])
      super(app)
      @tracer = tracer
      @parent_span = span
      @errors = errors
    end

    def call(env)
      span = @tracer.start_span(env[:method].to_s.upcase,
        child_of: parent_span(env),
        tags: {
          'component' => 'faraday',
          'span.kind' => 'client',
          'http.method' => env[:method],
          'http.url' => env[:url].to_s
        }
      )
      @tracer.inject(span.context, OpenTracing::FORMAT_RACK, env[:request_headers])
      @app.call(env).on_complete do |response|
        span.set_tag('http.status_code', response.status)
      end
    rescue *@errors => e
      span.set_tag('error', true)
      span.log_kv(event: 'error', :'error.object' => e)
      raise
    ensure
      span.finish
    end

    private

    def parent_span(env)
      context = env.request.context
      span = context.is_a?(Hash) && context[:span] || @parent_span

      if span
        span.respond_to?(:call) ? span.call : span
      end
    end
  end
end
