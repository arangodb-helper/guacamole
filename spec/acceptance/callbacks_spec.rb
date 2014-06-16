# -*- encoding : utf-8 -*-

require 'guacamole'
require 'acceptance/spec_helper'

class PoniesCollection
  include Guacamole::Collection
end

class Pony
  include Guacamole::Model

  before_save :my_before_save_handler
  after_save :my_after_save_handler

  def my_before_save_handler; end
  def my_after_save_handler; end
end

describe 'Support for Callbacks' do
  it 'should trigger the before and after save callbacks' do
    pony = Pony.new
    expect(pony).to receive(:my_before_save_handler).ordered
    # expect(pony).to receive(:persisted?).ordered
    expect(pony).to receive(:my_after_save_handler).ordered
    PoniesCollection.save(pony)
  end
end
