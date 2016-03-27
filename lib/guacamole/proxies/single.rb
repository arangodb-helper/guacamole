# -*- encoding: utf-8 -*-

require 'guacamole/proxies/relation'
require 'guacamole/edge_collection'

module Guacamole
  module Proxies
    class Single < Relation

      def resolve(query_result)
        return query_result.first.model unless query_result.empty?
        nil
      end

    end
  end
end
