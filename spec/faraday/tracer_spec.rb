require 'spec_helper'
require_relative './support/recording_tracer'

RSpec.describe Faraday::Tracer do
  let(:tracer) { RecordingTracer.new }

  it 'uses upcase HTTP method as span operation name' do
    call(method: :post)
    span = tracer.finished_spans.first
    expect(span.operation_name).to eq('POST')
  end

  it 'sets span.kind to client' do
    call(method: :post)
    span = tracer.finished_spans.first
    expect(span.tags['span.kind']).to eq('client')
  end

  describe 'parent_span' do
    it 'allows to pass a pre-created parent span' do
      parent_span = tracer.start_span("parent_span")
      expect(tracer).to receive(:start_span).with(any_args, hash_including(child_of: parent_span)).and_call_original
      call(method: :post, span: parent_span)
    end

    it 'allows to pass a block as a parent span provider' do
      parent_span = tracer.start_span("parent_span")
      parent_span_provider = lambda { parent_span }

      expect(tracer).to receive(:start_span).with(any_args, hash_including(child_of: parent_span)).and_call_original
      call(method: :post, span: parent_span_provider)
    end
  end

  describe 'error handling' do
    it 'finishes the span' do
      expect { call(app: lambda {|env| raise Timeout::Error }) }.to raise_error { |_|
        expect(tracer.finished_spans.first).not_to be_nil
      }
    end

    it 'marks the span as failed' do
      expect { call(app: lambda {|env| raise Timeout::Error }) }.to raise_error { |_|
        span = tracer.finished_spans.first

        expect(span.tags['error']).to eq(true)
      }
    end

    it 'logs the error' do
      exception = Timeout::Error.new
      expect { call(app: lambda {|env| raise exception }) }.to raise_error { |thrown_exception|
        span = tracer.finished_spans.first
        log = span.logs.first

        expect(span.logs).not_to be_empty
        expect(log[:event]).to eq('error')
        expect(log[:fields][:'error.object']).to eq(thrown_exception)
        expect(log[:fields][:'error.object']).to eq(exception)
      }
    end

    it 're-raise original exception' do
      expect { call(app: lambda {|env| raise Timeout::Error }) }.to raise_error(Timeout::Error)
    end
  end

  def call(options)
    span = options.delete(:span)
    app = options.delete(:app) || lambda {|env| env}
    env = Faraday::Env.from(options)
    allow(env).to receive(:on_complete).and_yield(double(status: 200))
    middleware = described_class.new(app, span: span, tracer: tracer)
    middleware.call(env)
  end
end
