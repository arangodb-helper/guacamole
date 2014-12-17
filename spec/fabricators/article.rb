# -*- encoding: utf-8 -*-

require 'fabricators/comment'

class Article
  include Guacamole::Model

  attribute :title, String
  attribute :comments, Array[Comment]
  attribute :unique_attribute, String
  attribute :location, Array[Float]

  validates :title, presence: true
end
