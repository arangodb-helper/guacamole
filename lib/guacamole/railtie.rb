# -*- encoding: utf-8 -*-

require 'guacamole'
require 'guacamole/configuration'

require 'rails'

module Guacamole
  # Class to hook into Rails configuration and initializer
  class Railtie < Rails::Railtie

    rake_tasks do
      load 'guacamole/railtie/database.rake'
    end

    config.guacamole = ::Guacamole::Configuration

    initializer 'guacamole.load-config' do
      config_file = Rails.root.join('config', 'guacamole.yml')
      if config_file.file?
        Guacamole::Configuration.load config_file
      end
    end

  end
end
