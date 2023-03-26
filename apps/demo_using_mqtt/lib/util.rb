# frozen_string_literal: true

class Util
  class << self
    def elapsed_time
      starting = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      yield
      ending = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      sprintf("%.3f ms", (ending - starting) * 1_000)
    end
  end
end
