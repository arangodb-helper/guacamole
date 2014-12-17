# -*- encoding : utf-8 -*-

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'active_support'
require 'fabrication'
require 'faker'
require 'logging'
require 'ashikawa-core'
require 'pry'
require 'timecop'

# This is required to remove the deprecation warning introduced in this commit:
# https://github.com/svenfuchs/i18n/commit/3b6e56e06fd70f6e4507996b017238505e66608c.
I18n.config.enforce_available_locales = false

class Fabrication::Generator::Guacamole < Fabrication::Generator::Base
  def self.supports?(klass)
    defined?(Guacamole) && klass.ancestors.include?(Guacamole::Model)
  end

  def persist
    collection = [_instance.class.name.pluralize, 'Collection'].join.constantize
    collection.save _instance
  end

  def validate_instance
    _instance.valid?
  end
end

Fabrication::Schematic::Definition::GENERATORS.unshift Fabrication::Generator::Guacamole

ENV['GUACAMOLE_ENV'] = 'test'

Guacamole.configure do |config|
  logger = Logging.logger['guacamole_logger']
  logger.add_appenders(
      Logging.appenders.file('log/acceptance.log')
  )
  logger.level = :info

  config.logger = logger

  config.load File.join(File.dirname(__FILE__), 'config', 'guacamole.yml')
end

begin
  Guacamole.configuration.database.create
rescue Ashikawa::Core::ClientError
  # Database already exists, don't worry
end

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.mock_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:each) do
    Guacamole.configuration.database.truncate
  end
end

# Collections for fabricator models

require 'fabricators/article'

class ArticlesCollection
  include Guacamole::Collection

  index :hash, on: :unique_attribute, unique: true
  index :geo, on: :location

  map do
    embeds :comments
  end
end

class PoniesCollection
  include Guacamole::Collection
end
