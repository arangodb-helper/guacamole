# -*- encoding : utf-8 -*-

require 'guacamole/proxies/array'
require 'guacamole/proxies/hash'
require 'guacamole/proxies/single'

module Guacamole
  # This is the default mapper class to map between Ashikawa::Core::Document and
  # Guacamole::Model instances.
  #
  # If you want to build your own mapper, you have to build at least the
  # `document_to_model` and `model_to_document` methods.
  #
  # @note If you plan to bring your own `DocumentModelMapper` please consider using an {Guacamole::IdentityMap}.
  class DocumentModelMapper
    # An attribute to encapsulate special mapping
    class Attribute
      # The name of the attribute with in the model
      #
      # @return [Symbol] The name of the attribute
      attr_reader :name

      # Additional options to be used for the mapping
      #
      # @return [Hash] The mapping options for the attribute
      attr_reader :options

      # Create a new attribute instance
      #
      # You must at least provide the name of the attribute to be mapped and
      # optionally pass configuration for the mapper when it processes this attribute.
      #
      # @param [Symbol] name The name of the attribute
      # @param [Hash] options Additional options to be passed
      # @option options [Edge] :via The Edge class this attribute relates to
      def initialize(name, options = {})
        @name    = name.to_sym
        @options = options
      end

      # The name of the getter for this attribute
      #
      # @returns [Symbol] The method name to read this attribute
      def getter
        name
      end

      def get_value(model)
        value = model.send(getter)

        value.is_a?(Guacamole::Query) ? value.entries : value
      end

      def type(model)
        model.send(:attribute_set)[name].type
      end

      # The name of the setter for this attribute
      #
      # @return [String] The method name to set this attribute
      def setter
        "#{name}="
      end

      # Should this attribute be mapped via an Edge in a Graph?
      #
      # @return [Boolean] True if there was an edge class configured
      def map_via_edge?
        !!edge_class
      end

      # The edge class to be used during the mapping process
      #
      # @return [Edge] The actual edge class
      def edge_class
        options[:via]
      end

      def inverse?
        !!options[:inverse]
      end

      # To Attribute instances are equal if their name is equal
      #
      # @param [Attribute] other The Attribute to compare this one to
      # @return [Boolean] True if both have the same name
      def ==(other)
        other.instance_of?(self.class) &&
          other.name == name
      end
      alias_method :eql?, :==
    end

    # The class to map to
    #
    # @return [class] The class to map to
    attr_reader :model_class

    # The arrays embedded in this model
    #
    # @return [Array] An array of embedded models
    attr_reader :models_to_embed

    # The list of Attributes to treat specially during the mapping process
    #
    # @return [Array<Attribute>] The list of special attributes
    attr_reader :attributes

    # Create a new instance of the mapper
    #
    # You have to provide the model class you want to map to.
    # The Document class is always Ashikawa::Core::Document
    #
    # @param [Class] model_class
    def initialize(model_class, identity_map = IdentityMap)
      @model_class          = model_class
      @identity_map         = identity_map
      @models_to_embed      = []
      @attributes           = []
    end

    class << self
      # Construct the {collection} class for a given model name.
      #
      # @example
      #   collection_class = collection_for(:user)
      #   collection_class == UsersCollection # would be true
      #
      # @note This is an class level alias for {DocumentModelMapper#collection_for}
      # @param [Symbol, String] model_name the name of the model
      # @return [Class] the {Collection} class for the given model name
      def collection_for(model_name)
        "#{model_name.to_s.classify.pluralize}Collection".constantize
      end
    end

    # construct the {collection} class for a given model name.
    #
    # @example
    #   collection_class = collection_for(:user)
    #   collection_class == userscollection # would be true
    #
    # @todo As of now this is some kind of placeholder method. As soon as we implement
    #       the configuration of the mapping (#12) this will change. Still the {DocumentModelMapper}
    #       seems to be a good place for this functionality.
    # @param [symbol, string] model_name the name of the model
    # @return [class] the {collection} class for the given model name
    def collection_for(model_name = model_class.name)
      self.class.collection_for model_name
    end

    # Map a document to a model
    #
    # Sets the revision, key and all attributes on the model
    #
    # @param [Ashikawa::Core::Document] document
    # @return [Model] the resulting model with the given Model class
    def document_to_model(document)
      to_model(document.key, document.revision, document.to_h)
    end

    def hash_to_model(hash)
      to_model(hash['_key'], hash['_revision'], hash)
    end

    def to_model(key, revision, hash)
      identity_map.retrieve_or_store model_class, key do
        model = model_class.new(hash)

        model.key = key
        model.rev = revision

        handle_related_documents(model)

        model
      end
    end

    # Map a model to a document
    #
    # This will include all embedded models
    #
    # @param [Model] model
    # @return [Ashikawa::Core::Document] the resulting document
    def model_to_document(model)
      document = model.attributes.dup.except(:key, :rev)

      handle_embedded_models(model, document)
      handle_related_models(document)

      document
    end

    # Declare a model to be embedded
    #
    # With embeds you can specify that the document in the
    # collection embeds a document that should be mapped to
    # a certain model. Your model has to specify an attribute
    # with the type Array (of this model).
    #
    # @param [Symbol] model_name Pluralized name of the model class to embed
    # @example A blogpost with embedded comments
    #   class BlogpostsCollection
    #     include Guacamole::Collection
    #
    #     map do
    #       embeds :comments
    #     end
    #   end
    #
    #   class Blogpost
    #     include Guacamole::Model
    #
    #     attribute :comments, Array[Comment]
    #   end
    #
    #   class Comment
    #     include Guacamole::Model
    #   end
    #
    #   blogpost = BlogpostsCollection.find('12313121')
    #   p blogpost.comments #=> An Array of Comments
    def embeds(model_name)
      @models_to_embed << model_name
    end

    # Mark an attribute of the model to be specially treated during mapping
    #
    # @param [Symbol] attribute_name The name of the model attribute
    # @param [Hash] options Additional options to configure the mapping process
    # @option options [Edge] :via The Edge class this attribute relates to
    # @example Define a relation via an Edge in a Graph
    #   class Authorship
    #     include Guacamole::Edge
    #
    #     from :users
    #     to :posts
    #   end
    #
    #   class BlogpostsCollection
    #     include Guacamole::Collection
    #
    #     map do
    #       attribute :author, via: Authorship
    #     end
    #   end
    def attribute(attribute_name, options = {})
      @attributes << Attribute.new(attribute_name, options)
    end

    # Returns a list of attributes that have an Edge class configured
    #
    # @return [Array<Attribute>] A list of attributes which all have an Edge class
    def edge_attributes
      attributes.select(&:map_via_edge?)
    end

    # Is this Mapper instance responsible for mapping the given model
    #
    # @param [Model] model The model to check against
    # @return [Boolean] True if the given model is an instance of #model_class. False if not.
    def responsible_for?(model)
      model.instance_of?(model_class)
    end

    # @api private
    def identity_map
      @identity_map
    end

    # @api private
    def handle_embedded_models(model, document)
      models_to_embed.each do |attribute_name|
        document[attribute_name] = model.send(attribute_name).map do |embedded_model|
          embedded_model.attributes.except(:key, :rev)
        end
      end
    end

    # @api private
    def handle_related_models(document)
      edge_attributes.each do |edge_attribute|
        document.delete(edge_attribute.name)
      end
    end

    # @api private
    def handle_related_documents(model)
      edge_attributes.each do |edge_attribute|
        model.send(edge_attribute.setter, build_proxy(model, edge_attribute))
      end
    end

    # @api private
    def build_proxy(model, edge_attribute)
      opts = { just_one: !edge_attribute_a_collection?(model, edge_attribute),
               inverse: edge_attribute.inverse? }

      case edge_attribute.type(model)
      when Virtus::Attribute::Collection::Type
        Proxies::Array.new(model, edge_attribute.edge_class, opts)
      when Virtus::Attribute::Hash::Type
        Proxies::Hash.new(model, edge_attribute.edge_class, opts)
      else
        Proxies::Single.new(model, edge_attribute.edge_class, opts)
      end
    end

    # @api private
    def edge_attribute_a_collection?(model, edge_attribute)
      model.class.attribute_set[edge_attribute.name].type.is_a?(Virtus::Attribute::Collection::Type) ||
        model.class.attribute_set[edge_attribute.name].type.is_a?(Virtus::Attribute::Hash::Type)
    end
  end
end
