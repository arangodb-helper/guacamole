# -*- encoding : utf-8 -*-
require 'active_support/concern'
# Cherry Pick not possible
require 'active_model'
require 'virtus'

module Guacamole
  module Model
    extend ActiveSupport::Concern

    included do
      include ActiveModel::Validations
      include ActiveModel::Naming
      include ActiveModel::Conversion
      include Virtus.model

      attribute :key, String
      attribute :rev, String
      attribute :created_at, DateTime
      attribute :updated_at, DateTime

      def persisted?
        key.present?
      end

      # For ActiveModel::Conversion compliance only, please use key
      def id
        key
      end
    end
  end
end
