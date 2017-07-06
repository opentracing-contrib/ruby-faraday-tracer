class RecordingTracer
  attr_reader :finished_spans

  def initialize
    @finished_spans = []
  end

  def start_span(operation_name, **)
    Span.new(self, operation_name)
  end

  def inject(*)
  end

  class Span
    attr_reader :operation_name

    def initialize(tracer, operation_name)
      @tracer = tracer
      @operation_name = operation_name
    end

    def finish
      @tracer.finished_spans << self
    end

    def context
      {}
    end

    def set_tag(*)
    end
  end
end
