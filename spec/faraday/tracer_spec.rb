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

  def call(options)
    app = lambda {|env| env}
    env = Faraday::Env.from(options)
    allow(env).to receive(:on_complete).and_yield(double(status: 200))
    middleware = described_class.new(app, tracer: tracer)
    middleware.call(env)
  end
end
