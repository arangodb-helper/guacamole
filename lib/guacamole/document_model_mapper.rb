# -*- encoding : utf-8 -*-

require 'guacamole/proxies/referenced_by'
require 'guacamole/proxies/references'

module Guacamole
  # This is the default mapper class to map between Ashikawa::Core::Document and
  # Guacamole::Model instances.
  #
  # If you want to build your own mapper, you have to build at least the
  # `document_to_model` and `model_to_document` methods.
  #
  # @note If you plan to bring your own `DocumentModelMapper` please consider using an {Guacamole::IdentityMap}.
  class DocumentModelMapper
    # The class to map to
    #
    # @return [class] The class to map to
    attr_reader :model_class

    # The arrays embedded in this model
    #
    # @return [Array] An array of embedded models
    attr_reader :models_to_embed
    attr_reader :referenced_by_models
    attr_reader :referenced_models

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
      @referenced_by_models = []
      @referenced_models    = []
    end

    class << self
      # construct the {collection} class for a given model name.
      #
      # @example
      #   collection_class = collection_for(:user)
      #   collection_class == userscollection # would be true
      #
      # @note This is an class level alias for {DocumentModelMapper#collection_for}
      # @param [symbol, string] model_name the name of the model
      # @return [class] the {collection} class for the given model name
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
    def collection_for(model_name)
      self.class.collection_for model_name
    end

    # Map a document to a model
    #
    # Sets the revision, key and all attributes on the model
    #
    # @param [Ashikawa::Core::Document] document
    # @return [Model] the resulting model with the given Model class
    # rubocop:disable MethodLength
    def document_to_model(document)
      identity_map.retrieve_or_store model_class, document.key do
        model = model_class.new(document.to_h)

        referenced_by_models.each do |ref_model_name|
          model.send("#{ref_model_name}=", Proxies::ReferencedBy.new(ref_model_name, model))
        end

        referenced_models.each do |ref_model_name|
          model.send("#{ref_model_name}=", Proxies::References.new(ref_model_name, document)) if document["#{ref_model_name}_id"].present?
        end

        model.key = document.key
        model.rev = document.revision

        model
      end
    end
    # rubocop:enable MethodLength

    # Map a model to a document
    #
    # This will include all embedded models
    #
    # @param [Model] model
    # @return [Ashikawa::Core::Document] the resulting document
    # rubocop:disable MethodLength
    def model_to_document(model)
      document = model.attributes.dup.except(:key, :rev)
      models_to_embed.each do |attribute_name|
        document[attribute_name] = model.send(attribute_name).map do |embedded_model|
          embedded_model.attributes.except(:key, :rev)
        end
      end

      referenced_models.each do |ref_model_name|
        ref_key = [ref_model_name.to_s, 'id'].join('_').to_sym
        ref_model = model.send ref_model_name
        document[ref_key] = ref_model.key if ref_model.present?
        document.delete(ref_model_name)
      end

      referenced_by_models.each do |ref_model_name|
        document.delete(ref_model_name)
      end

      document
    end
    # rubocop:enable MethodLength

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

    def referenced_by(model_name)
      @referenced_by_models << model_name
    end

    def references(model_name)
      @referenced_models << model_name
    end

    private

    def identity_map
      @identity_map
    end
  end
end
