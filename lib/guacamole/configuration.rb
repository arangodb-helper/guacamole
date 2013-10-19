# -*- encoding : utf-8 -*-

require 'logger'
require 'forwardable'

require 'guacamole/document_model_mapper'

module Guacamole

  class << self
    def configure(&config_block)
      config_block.call configuration

      configuration
    end

    def configuration
      @configuration ||= Configuration
    end
  end

  # This class holds the configuration for Guacamole.
  class Configuration
    attr_accessor :database, :default_mapper, :logger

    class << self
      extend Forwardable

      def_delegators :configuration, :database, :database=, :default_mapper=, :logger=

      def default_mapper
        configuration.default_mapper || (self.default_mapper = Guacamole::DocumentModelMapper)
      end

      def logger
        configuration.logger ||= default_logger
      end

      private

      def configuration
        @configuration ||= new
      end

      def default_logger
        default_logger       = Logger.new(STDOUT)
        default_logger.level = Logger::INFO
        default_logger
      end
    end
  end
end
