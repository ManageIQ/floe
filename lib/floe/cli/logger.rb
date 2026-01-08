# frozen_string_literal: true

require 'logger'

module Floe
  class CLI
    class Logger < ::Logger
      attr_accessor :execution_id

      def initialize(...)
        super

        original_formatter = formatter || ::Logger::Formatter.new
        self.formatter = proc do |severity, time, progname, msg|
          prefix = execution_id ? "[#{execution_id}] " : ""
          original_formatter.call(severity, time, progname, "#{prefix}#{msg}")
        end
      end
    end
  end
end
