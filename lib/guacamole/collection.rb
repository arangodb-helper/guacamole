# -*- encoding : utf-8 -*-

require 'guacamole/query'

require 'active_support/concern'
require 'active_support/core_ext/string/inflections'

module Guacamole
  module Collection
    extend ActiveSupport::Concern

    module ClassMethods
      extend Forwardable
      def_delegators :mapper, :model_to_document
      def_delegator :connection, :fetch, :fetch_document

      attr_accessor :connection, :mapper, :database

      def database
        @database ||= Guacamole.configuration.database
      end

      def connection
        @connection ||= database[collection_name]
      end

      def mapper
        @mapper ||= Guacamole.configuration.default_mapper.new(model_class)
      end

      def collection_name
        @collection_name ||= name.gsub(/Collection\z/, '').underscore
      end

      def model_class
        @model_class ||= collection_name.singularize.camelcase.constantize
      end

      def by_key(key)
        mapper.document_to_model connection.fetch(key)
      end

      def save(model)
        return false unless model.valid?

        add_timestamps_to_model(model)
        create_document_from(model)
        model
      end

      def delete(key)
        fetch_document(key).delete
        key
      end

      def replace(model)
        return false unless model.valid?

        model.updated_at = Time.now
        replace_document_from(model)
        model
      end

      def by_example(example)
        query = all
        query.example = example
        query
      end

      def all
        Query.new(connection.query, mapper)
      end

      def add_timestamps_to_model(model)
        timestamp = Time.now
        model.created_at = timestamp
        model.updated_at = timestamp
      end

      def create_document_from(model)
        document = connection.create_document(model_to_document(model))

        model.key = document.key
        model.rev = document.revision

        document
      end

      def replace_document_from(model)
        document = model_to_document(model)
        response = connection.replace(model.key, document)

        model.rev = response['_rev']

        document
      end

    end
  end
end
