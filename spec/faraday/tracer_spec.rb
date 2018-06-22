require 'spec_helper'

RSpec.describe Faraday::Tracer do
  let(:tracer) { Test::Tracer.new }

  it 'uses upcase HTTP method as span operation name' do
    call(method: :post)
    expect(tracer).to have_span('POST').finished
  end

  it 'sets span.kind to client' do
    call(method: :post)
    expect(tracer).to have_span.with_tag('span.kind', 'client')
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
        expect(tracer).to have_spans.finished
      }
    end

    it 'marks the span as failed' do
      expect { call(app: lambda {|env| raise Timeout::Error }) }.to raise_error { |_|
        expect(tracer).to have_span.with_tag('error', true)
      }
    end

    it 'logs the error' do
      exception = Timeout::Error.new
      expect { call(app: lambda {|env| raise exception }) }.to raise_error { |thrown_exception|
        expect(tracer).to have_span.with_log(event: 'error', :'error.object' => thrown_exception)
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
