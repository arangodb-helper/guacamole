# -*- encoding : utf-8 -*-

require 'hamster/hash'

module Guacamole
  # This class implements the 'Identity Map' pattern
  # ({http://www.martinfowler.com/eaaCatalog/identityMap.html Fowler, EAA, 195}) to
  # ensure only one copy of the same database document is present in memory within
  # the same session. Internally a `Hamster::Hash` is used. This hash implementation
  # is immutable and thus it is safe to use the current `IdentityMap`
  # implementation in concurrent situations.
  #
  # The `IdentityMap` should be purged after any unit of work (i.e. a request).
  # If used in Rails the {IdentityMap::Session} middleware will automatically
  # be registered. For other Rack-based use cases you must register it yourself.
  # For all other use cases you need to take when to call {Guacamole::IdentityMap.reset} all
  # by yourself.
  class IdentityMap
    # The `IdentityMap::Session` acts as Rack middleware to reset the {IdentityMap}
    # before each request.
    class Session
      # Create a new instance of the `Session` middleware
      #
      # You must pass an object that responds to `call` in the constructor. This
      # will be the called after the `IdentityMap` has been purged.
      #
      # @param [#call] app Any object that responds to `call`
      def initialize(app)
        @app = app
      end

      # Run the concrete middleware
      #
      # This satisfies the Rack interface and will be called to reset the `IdentityMap`
      # before each request. In the end the `@app` will be called.
      #
      # @param [Hash] env The environment of the Rack request
      # @return [Array] a Rack compliant response array
      def call(env)
        Guacamole.logger.debug '[SESSION] Resetting the IdentityMap'
        IdentityMap.reset

        @app.call(env)
      end
    end

    class << self
      # Purges all stored object from the map by setting the internal structure to `nil`
      #
      # @return [nil]
      def reset
        @identity_map_instance = nil
      end

      # Add an object to the map
      #
      # The object must implement a `key` method. There is *no* check if that method is present.
      #
      # @param [Object#key] object Any object that implements the `key` method (and has a `class`)
      # @return [Object#key] the object which just has been stored
      def store(object)
        @identity_map_instance = identity_map_instance.put(key_for(object), object)
        object
      end

      # Retrieves a stored object from the map
      #
      # @param [Class] klass The class of the object you want to get
      # @param [Object] key Whatever is the key of that object
      # @return [Object] the stored object
      def retrieve(klass, key)
        identity_map_instance.get key_for(klass, key)
      end

      # Retrieves a stored object or adds it based on the block if it is not already present
      #
      # This can be used to retrieve and store in one step. See {Guacamole::DocumentModelMapper#document_to_model}
      # for an example.
      #
      # @param [Class] klass The class of the object you want to get
      # @param [Object] key Whatever is the key of that object
      # @yield A block if the object is not already present
      # @yieldreturn [Object#read] the object to store. The `key` and `class` should match with input params
      # @return [Object] the stored object
      def retrieve_or_store(klass, key, &block)
        return retrieve(klass, key) if include?(klass, key)
        store block.call
      end

      # Tests if the map contains some object
      #
      # The method accepts either a `class` and `key` or just any `Object` that responds to
      # `key`. Supporting both is made for your convenience.
      #
      # @param [Object#read, Class] object_or_class Either the object to check or the `class`
      #                                             of the object you're looking for
      # @param [Object, nil] key In case you provided a `Class` as first parameter you must
      #                          provide the key for the object here
      # @return [true, false] does the map contain the object or not
      def include?(object_or_class, key = nil)
        identity_map_instance.key? key_for(object_or_class, key)
      end

      # Constructs the key used internally by the map
      #
      # @param [Object#read, Class] object_or_class Either an object or a `Class`
      # @param [Object, nil] key In case you provided a `Class` as first parameter you must
      #                          provide the key for the object here
      # @return [Array(Class, Object)] the created key
      def key_for(object_or_class, key = nil)
        key ? [object_or_class, key] : [object_or_class.class, object_or_class.key]
      end

      # The internally used map
      #
      # @api private
      # @return [Hamster::Hash] an instance of an immutable hash
      def identity_map_instance
        @identity_map_instance ||= Hamster.hash
      end
    end
  end
end
