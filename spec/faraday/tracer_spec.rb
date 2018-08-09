require 'spec_helper'

RSpec.describe Faraday::Tracer do
  let(:tracer) { Test::Tracer.new }

  shared_examples 'tracing' do |request_method|
    let(:make_request) { method(request_method) }

    it 'uses upcase HTTP method as span operation name' do
      make_request.call(method: :post)
      expect(tracer).to have_span('POST').finished
    end

    it 'uses provided span_name as span operation name' do
      span_name = 'custom span name'
      make_request.call(method: :post, span_name: span_name)
      expect(tracer).to have_span(span_name).finished
    end

    it 'sets span.kind to client' do
      make_request.call(method: :post)
      expect(tracer).to have_span.with_tag('span.kind', 'client')
    end

    it 'sets peer.service when service_name is provided' do
      service_name = 'service-name'
      make_request.call(method: :post, service_name: service_name)
      expect(tracer).to have_span.with_tag('peer.service', service_name)
    end

    describe 'parent_span' do
      it 'allows to pass a pre-created parent span' do
        parent_span = tracer.start_span('parent_span')
        expect(tracer).to receive(:start_span).with(any_args, hash_including(child_of: parent_span)).and_call_original
        make_request.call(method: :post, span: parent_span)
      end

      it 'allows to pass a block as a parent span provider' do
        parent_span = tracer.start_span('parent_span')
        parent_span_provider = -> { parent_span }

        expect(tracer).to receive(:start_span).with(any_args, hash_including(child_of: parent_span)).and_call_original
        make_request.call(method: :post, span: parent_span_provider)
      end
    end

    describe 'error handling' do
      it 'finishes the span' do
        exception = Timeout::Error.new
        expect { make_request.call(app: ->(_env) { raise exception }) }.to raise_error(exception)
        expect(tracer).to have_spans.finished
      end

      it 'marks the span as failed' do
        exception = Timeout::Error.new
        expect { make_request.call(app: ->(_env) { raise exception }) }.to raise_error(exception)
        expect(tracer).to have_span.with_tag('error', true)
      end

      it 'logs the error' do
        exception = Timeout::Error.new
        expect { make_request.call(app: ->(_env) { raise exception }) }.to raise_error(exception)
        expect(tracer).to have_span.with_log(event: 'error', :'error.object' => exception)
      end

      it 're-raise original exception' do
        exception = Timeout::Error.new
        expect { make_request.call(app: ->(_env) { raise exception }) }.to raise_error(exception)
      end
    end
  end

  context 'when span is defined using the builder' do
    include_examples 'tracing', :make_builder_request
  end

  context 'when span is defined in the request context' do
    include_examples 'tracing', :make_explicit_request
  end

  def make_builder_request(options)
    app = options.delete(:app) || ->(_app_env) { [200, {}, 'OK'] }
    request_options = options.slice(:span, :span_name, :service_name)

    connection = Faraday.new do |builder|
      builder.use Faraday::Tracer, request_options.merge(tracer: tracer)
      builder.adapter :test do |stub|
        stub.post('/', &app)
      end
    end

    connection.post('/')
  end

  def make_explicit_request(options)
    app = options.delete(:app) || ->(_app_env) { [200, {}, 'OK'] }
    request_options = options.slice(:span, :span_name, :service_name)

    connection = Faraday.new do |builder|
      builder.use Faraday::Tracer, tracer: tracer
      builder.adapter :test do |stub|
        stub.post('/', &app)
      end
    end

    connection.post('/') do |request|
      request.options.context = request_options
    end
  end
end
