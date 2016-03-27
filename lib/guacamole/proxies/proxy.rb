# -*- encoding : utf-8 -*-

module Guacamole
  module Proxies
    # This is the base class for the association proxies. Proxies are only
    # needed for non-embedded relations between objects. Embedded objects are
    # taken care of by Virtus.
    #
    # The `Proxy` class undefines most methods and passes them to the
    # `@target`.  The `@target` will be a lambda which will lazy query the
    # requested objects from the database.
    #
    # Concrete proxy classes are:
    #
    #  * {Guacamole::Proxies::ReferencedBy}: This will handle one-to-many associations
    #  * {Guacamole::Proxies::References}: This will handle many-to-one associations
    class Proxy < BasicObject
      # Despite using BasicObject we still need to remove some method to get a near transparent proxy
      instance_methods.each do |method|
        undef_method(method) unless method =~ /^__/
      end

      def target
      end

      def method_missing(meth, *args, &blk)
        target.send(meth, *args, &blk)
      end

      def respond_to_missing?(name, include_private = false)
        target.respond_to?(name, include_private)
      end

   end
  end
end
