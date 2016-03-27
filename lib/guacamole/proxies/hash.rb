# -*- encoding: utf-8 -*-

require 'guacamole/proxies/relation'
require 'guacamole/edge_collection'

module Guacamole
  module Proxies
    class Hash < Relation

      def resolve(query_result)
        if relates_to_collection?
          query_result.map{ |e| [e.edge_attributes['hash_key'], e.model] }.to_h
        else
          # todo change to Guacamole::Proxies::Single for inverse relations
          query_result.first.model
        end
      end

    end
  end
end
