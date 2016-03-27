# -*- encoding: utf-8 -*-

require 'guacamole/proxies/proxy'
require 'guacamole/edge_collection'

module Guacamole
  module Proxies
    # This class smells of :reek:TooManyInstanceVariables
    class Relation < Proxy

      attr_writer :query

      # This method smells of :reek:TooManyStatements
      def initialize(model, edge_class, options = {})
        @model      = model
        @edge_class = edge_class
        @options    = options
      end

      def edge_collection
        EdgeCollection.for(@edge_class)
      end

      def direction
        @options[:inverse] ? :inbound : :outbound
      end

      def relates_to_collection?
        !@options[:just_one]
      end

      def query
        @query ||= edge_collection.neighbors(@model, direction)
      end

      def target
        @target ||= resolve(query_result)
      end

      def resolve(query_result)
        query_result
      end

      def query_result
        query.to_a
      end

      def method_missing(meth, *args, &blk)
        if query.methods.include?(meth) and query.method(meth).owner =~ /Guacamole::/
          query.send(meth, *args, &blk)
        else
          super(meth,*args,&blk)
        end
      end

      def respond_to_missing?(name, include_private = false)
        query.has_method?(name) || super(name, include_private)
      end

    end
  end
end
