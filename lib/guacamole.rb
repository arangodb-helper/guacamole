# -*- encoding : utf-8 -*-

require 'active_support/core_ext'

require 'guacamole/version'
require 'guacamole/configuration'
require 'guacamole/model'
require 'guacamole/collection'
require 'guacamole/document_model_mapper'

if defined?(Rails)
  require 'guacamole/railtie'
end

module Guacamole
end
