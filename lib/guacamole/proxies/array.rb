# -*- encoding: utf-8 -*-

require 'guacamole/proxies/relation'
require 'guacamole/edge_collection'

module Guacamole
  module Proxies
    class Array < Relation

      def resolve(query_result)
        if relates_to_collection?
          return query_result.map{ |e| e.model }
        else
          return query_result.first.model
        end
      end
    end
  end
end

