# -*- encoding : utf-8 -*-

require 'spec_helper'
require 'guacamole/model'

class TestModel
  include Guacamole::Model
end

describe Guacamole::Model do
  subject { TestModel }
  let(:current_time) { DateTime.now }

  describe 'module inclusion' do
    it 'should include Virtus.model' do
      expect(subject.ancestors.any? do |ancestor|
        ancestor.to_s.include? 'Virtus'
      end).to be_true
    end

    it 'should include ActiveModel::Validation' do
      expect(subject.ancestors).to include ActiveModel::Validations
    end

    it 'should include ActiveModel::Naming' do
      expect(subject.ancestors).to include ActiveModel::Naming
    end

    it 'should include ActiveModel::Conversion' do
      expect(subject.ancestors).to include ActiveModel::Conversion
    end
  end

  describe 'default attributes' do
    subject { TestModel.new }

    it 'should add the key attribute' do
      subject.key = '12345'
      expect(subject.key).to eq '12345'
    end

    it 'should add the rev attribute' do
      subject.rev = '98765'
      expect(subject.rev).to eq '98765'
    end

    it 'should add the created_at attribute' do
      subject.created_at = current_time
      expect(subject.created_at).to be current_time
    end

    it 'should add the updated_at attribute' do
      subject.updated_at = current_time
      expect(subject.updated_at).to be current_time
    end
  end

  describe 'persisted?' do
    subject { TestModel.new }

    it 'should be persisted if it has a key' do
      subject.key = 'my_key'
      expect(subject.persisted?).to be_true
    end

    it "should not be persisted if it doesn't have a key" do
      subject.key = nil
      expect(subject.persisted?).to be_false
    end
  end

  describe 'id' do
    subject { TestModel.new }

    it 'should alias key to id for ActiveModel::Conversion compliance' do
      subject.key = 'my_key'
      expect(subject.id).to eq 'my_key'
    end
  end
end
