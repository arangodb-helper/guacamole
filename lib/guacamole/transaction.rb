# -*- encoding : utf-8 -*-

require 'ashikawa-core'

module Guacamole
  # Encapsulates a server side transaction.
  #
  # This is considered for internal use only. It will only work for persisting vertices and
  # edges between them.
  #
  # @api private
  class Transaction
    # The original collection class to gain access to the mapper and database connection
    #
    # @return [Collection] The original collection
    attr_reader :collection

    # The model to persist and starting point for looking up edges and related vertices
    #
    # @return [Model] The model to persist
    attr_reader :model

    # A simple structure to build the vertex information we need to pass to the transaction code.
    class Vertex < Struct.new(:model, :collection, :document, :edge_attributes)
      # The key of the wrapped model
      #
      # @return [String] The key of the model
      def key
        model.key
      end

      # The id of the wrapped model
      #
      # @return [String] The id of the model
      def id
        model.arangodb_id
      end

      # An ID suitable for resolving the edges in the transaction
      #
      # If the model was never saved and thus don't have an id yet we will
      # return Model#object_id instead.
      #
      # @return [String] The ID suitable for persisting the edges
      def id_for_edge
        model.arangodb_id || model.object_id
      end

      # Creates a hash to be used in JSON serialization for the transaction
      #
      # @return [Hash] A hash with the required information to be passed to the database
      def as_json(*)
        {
          object_id: model.object_id,
          collection: collection,
          document: document,
          _key: key,
          _id: id
        }
      end
    end

    # Factory class to create the concrete TargetState instances
    class TargetStatesBuilder
      class << self
        # The factory method
        #
        # It will create a SubGraphTargetState instance if there are any relations presents. If not
        # it will create a VertexTargetState instance.
        #
        # @param model [Model] The model to persist
        # @param collection [Collection] The original collection initiating this call
        # @return [VertexTargetState, SubGraphTargetState] Either a VertexTargetState instance
        #                                                  or a SubGraphTargetState instance
        def build(model, collection)
          if collection.mapper.edge_attributes.empty?
            [VertexTargetState.new(model, collection)]
          else
            collection.mapper.edge_attributes.map { |edge_attribute| SubGraphTargetState.new(model, edge_attribute) }
          end
        end
      end
    end

    # Describes the target state of the graph for a model without relations
    class VertexTargetState
      # The original collection class to gain access to the mapper and database connection
      #
      # @return [Collection] The original collection
      attr_reader :collection

      # The model to persist and starting point for looking up edges and related vertices
      #
      # @return [Model] The model to persist
      attr_reader :model

      # Creates a new VertexTargetState
      #
      # This will be used to persist models without any relations
      #
      # @param model [Model] The model to persist
      # @param collection [Collection] The original collection
      def initialize(model, collection)
        @model      = model
        @collection = collection
      end

      # Returns a Vertex data structure
      #
      # @return [Vertex] A representation of the model and related information to be passed to the database
      def vertex
        Vertex.new(model,
                   collection.collection_name,
                   collection.mapper.model_to_document(model))
      end

      # The name of the edge collection to be used
      #
      # This will be `nil` and is just for interface conformance
      def edge_collection_name
        nil
      end

      # Returns the vertex wrapped in an Array
      #
      # @return [Array<Vertex>] The vertex to persist
      def from_vertices
        [vertex]
      end

      # Return an empty Array to comply to the interface
      #
      # @return [Array] An empty array
      def to_vertices
        []
      end

      # Creates a hash to be used in JSON serialization for the transaction
      #
      # @return [Hash] A hash with the required information to be passed to the database
      def as_json(*)
        {
          name: nil,
          fromVertices: from_vertices.as_json,
          toVertices: to_vertices,
          edges: [],
          oldEdges: []
        }
      end
    end

    # Describes the target state of the graph for a model with relations
    class SubGraphTargetState
      # The model to start looking for relations
      #
      # @return [Model] The start model to start looking for relations
      attr_reader :start_model

      # The edge attribute to resolve edges and related models
      #
      # @return [Attribute] The edge attribute to resolve edges and relations
      attr_reader :edge_attribute

      ModelWithAttributes = Struct.new(:model, :edge_attributes)

      # Initializes a new SubGraphTargetState instance
      #
      # @param model [Model] The start model
      # @param edge_attribute [Attribute] The edge attribute to use
      def initialize(model, edge_attribute)
        @edge_attribute = edge_attribute
        @start_model    = model
      end

      # The class of the edge to be persisted
      #
      # @return [Class] The class of the edge
      def edge_class
        edge_attribute.edge_class
      end

      # The edge collection to be used
      #
      # @return [EdgeCollection] The edge collection to be used
      def edge_collection
        EdgeCollection.for(edge_class)
      end

      # The name of the edge collection
      #
      # @return [String] The name of the edge collection
      def edge_collection_name
        edge_collection.collection_name
      end

      # Determines the mapper for a given model based on the edge collection
      #
      # @param model [Model] The model we need a mapper for
      # @return mapper [Mapper] The mapper for that model based on the edge collection
      def mapper_for_model(model)
        edge_collection.mapper_for_start(model)
      end

      # The document mapped from the model
      #
      # @param model [Model] The model we want to map
      # @return [Document] A mapped document
      def model_to_document(model)
        mapper_for_model(model).model_to_document(model)
      end

      # The related models of the start model based on the edge attribute
      #
      # @return [Array<Model>] A list of related models
      def related_models
        value = edge_attribute.get_value(start_model)
        return [] unless value
        attr_type = edge_attribute.type(start_model)

        case attr_type
        when Virtus::Attribute::Hash::Type
          [ value.map{ |k,v| ModelWithAttributes.new(v, { hash_key: k }) } ].compact.flatten
        when Virtus::Attribute::Collection::Type
          [ value.map{ |v|  ModelWithAttributes.new(v, {}) } ].compact.flatten
        else
          [ ModelWithAttributes.new(value, {}) ]
        end
      end

      # The keys of the old edge documents
      #
      # @return [Array<String>] A list of edge keys
      def old_edge_keys
        case start_model
        when edge_class.from_collection.model_class
          edge_collection.by_example(_from: start_model.arangodb_id).map(&:key)
        when edge_class.to_collection.model_class
          edge_collection.by_example(_to: start_model.arangodb_id).map(&:key)
        end
      end

      # The from vertices
      #
      # @return [Array<Vertex>] A list of from vertices
      def from_vertices
        case start_model
        when edge_class.from_collection.model_class
          [Vertex.new(start_model, edge_class.from_collection.collection_name, model_to_document(start_model), {})]
        when edge_class.to_collection.model_class
          related_models.map do |related|
            Vertex.new(related.model, edge_class.from_collection.collection_name, model_to_document(related.model),related.edge_attributes)
          end
        end
      end

      # All to vertices
      #
      # @return [Array<Vertex>] A list of all to vertices
      def to_vertices
        case start_model
        when edge_class.from_collection.model_class
          related_models.map do |related|
            Vertex.new(related.model, edge_class.to_collection.collection_name, model_to_document(related.model), related.edge_attributes)
          end
        when edge_class.to_collection.model_class
          [Vertex.new(start_model, edge_class.to_collection.collection_name, model_to_document(start_model), {})]
        end
      end

      # The edges of the sub graph
      #
      # @return [Array<Hash>] A list of hashes representing the edges
      def edges
        t = from_vertices.product(to_vertices).map do |from_vertex, to_vertex|
          { _from: from_vertex.id_for_edge, _to: to_vertex.id_for_edge, attributes: to_vertex.edge_attributes }
        end
      end

      # Creates a hash to be used in JSON serialization for the transaction
      #
      # @return [Hash] A hash with the required information to be passed to the database
      def as_json(*)
        {
          name: edge_collection_name,
          fromVertices: from_vertices.as_json,
          toVertices: to_vertices.as_json,
          edges: edges,
          oldEdges: old_edge_keys
        }
      end
    end

    class << self
      # Runs the transaction specified by the options
      #
      # @param options [Hash] A hash containing the original model and collection
      def run(options)
        new(options).execute_transaction
      end
    end

    # Creates a new Transaction
    #
    # @param options [Hash] A hash containing the original model and collection
    def initialize(options)
      @collection = options[:collection]
      @model      = options[:model]
      init_connection_to_database
    end

    # A list of TargetStates
    #
    # @return [Array<VertexTargetState, SubGraphTargetState>] The list of target states to apply
    def edge_collections
      TargetStatesBuilder.build(model, collection)
    end

    # A list of collections we will write to
    #
    # @return [Array<String>] A list of the collection names we will write to
    def write_collections
      edge_collections.flat_map do |target_state|
        [target_state.edge_collection_name] +
          (target_state.from_vertices + target_state.to_vertices).map(&:collection)
      end.uniq.compact
    end

    # A list of collections we will read from
    #
    # @return [Array<String>] A list of the collection names we will read from
    def read_collections
      write_collections
    end

    # The parameters to send to the database
    #
    # @return [Hash] A hash with the transaction parameters
    def transaction_params
      {
        edgeCollections: edge_collections,
        graph: Guacamole.configuration.graph.name,
        log_level: 'debug'
      }
    end

    # Executes the actual transaction on the database
    #
    # @api private
    def execute_transaction
      transaction.execute(transaction_params.as_json)
    end

    # The JS code of the transaction
    #
    # @return [String] A JavaScript string with the transaction code
    # @api private
    def transaction_code
      File.read(Guacamole.configuration.shared_path.join('transaction.js'))
    end

    # A transaction instance from the database
    #
    # return [Ashikawa::Core::Transaction] A raw transaction to execute the Transaction on the database
    # @api private
    def transaction
      transaction = database.create_transaction(transaction_code,
                                                write: write_collections,
                                                read:  read_collections)
      transaction.wait_for_sync = true

      transaction
    end

    private

    # The connection to the database
    def database
      collection.database
    end

    # Requests the collection from the database
    #
    # If the collection was not existing before this will create it.
    # If the collection already exists, this will be a no-op
    def init_connection_to_database
      @collection.connection
    end
  end
end
