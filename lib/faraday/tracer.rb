# frozen_string_literal: true

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
    # @param span_name [String, nil] The name of the span to create.
    # @param service_name [String, nil] Remote service name (for some
    #        unspecified definition of "service")
    # @param tracer [OpenTracing::Tracer] A tracer to be used when start_span, and inject
    #        is called.
    # @param errors [Array<Class>] An array of error classes to be captured by the tracer
    #        as errors. Errors are **not** muted by the middleware.
    def initialize( # rubocop:disable Metrics/ParameterLists
        app,
        span: nil,
        span_name: nil,
        service_name: nil,
        tracer: OpenTracing.global_tracer,
        errors: [StandardError]
    )
      super(app)
      @tracer = tracer
      @parent_span = span
      @span_name = span_name
      @service_name = service_name
      @errors = errors
    end

    def call(env)
      span = @tracer.start_span(span_name(env),
                                child_of: parent_span(env),
                                tags: prepare_tags(env))
      @tracer.inject(span.context, OpenTracing::FORMAT_RACK, env[:request_headers])
      @app.call(env).on_complete do |response|
        span.set_tag('http.status_code', response.status)

        if response.status >= 500
          span.set_tag('error', true)
          span.log_kv(event: 'error', message: response.body.to_s)
        end
      end
    rescue *@errors => e
      span.set_tag('error', true)
      span.log_kv(event: 'error', :'error.object' => e)
      raise
    ensure
      span.finish
    end

    private

    def span_name(env)
      context = env.request.context if env.request.respond_to?(:context)
      context.is_a?(Hash) && context[:span_name] || @span_name || env[:method].to_s.upcase
    end

    def parent_span(env)
      context = env.request.context if env.request.respond_to?(:context)
      span = context.is_a?(Hash) && context[:span] || @parent_span
      return unless span

      span.respond_to?(:call) ? span.call : span
    end

    def prepare_tags(env)
      tags = {
        'component' => 'faraday',
        'span.kind' => 'client',
        'http.method' => env[:method],
        'http.url' => env[:url].to_s
      }

      if (service_name = peer_service(env))
        tags['peer.service'] = service_name
      end

      tags
    end

    def peer_service(env)
      context = env.request.context if env.request.respond_to?(:context)
      context.is_a?(Hash) && context[:service_name] || @service_name
    end
  end
end
