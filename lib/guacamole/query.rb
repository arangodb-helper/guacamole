# -*- encoding : utf-8 -*-

module Guacamole
  # Build a query for ArangoDB
  class Query
    include Enumerable

    attr_reader :connection
    attr_reader :mapper
    attr_accessor :example
    attr_accessor :options

    def initialize(connection, mapper)
      @connection = connection
      @mapper = mapper
      @options = {}
    end

    def each
      return to_enum(__callee__) unless block_given?

      iterator = ->(document) { yield mapper.document_to_model(document) }

      if example
        connection.by_example(example, options).each(&iterator)
      else
        connection.all(options).each(&iterator)
      end
    end

    def limit(limit)
      options[:limit] = limit
      self
    end

    def skip(skip)
      options[:skip] = skip
      self
    end
  end
end
