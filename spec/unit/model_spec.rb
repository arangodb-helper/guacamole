# -*- encoding : utf-8 -*-

require 'spec_helper'
require 'guacamole/model'

class TestModelsCollection
  include Guacamole::Collection
end

class OtherModelsCollection
  include Guacamole::Collection
end

class TestModel
  include Guacamole::Model
end

class OtherModel
  include Guacamole::Model
end

describe Guacamole::Model do
  subject { TestModel }
  let(:current_time) { Time.now }

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

  describe '==' do
    let(:key) { double('Key') }
    let(:rev) { double('Rev') }
    let(:updated_at) { Time.now }
    let(:content) { double('String') }
    let(:unixy_time) { 1_445_444_940 } # If you read this line and understand it, you get a beer
    let(:timestamp_without_nsecs) { Time.at(unixy_time, 0) }
    let(:timestamp_with_nsecs) { Time.at(unixy_time, 42) }

    subject { TestModel.new(key: key, rev: rev, updated_at: updated_at, content: content) }
    let(:comparison_object) { TestModel.new(subject.attributes) }

    it 'should not be equal if it is a different class' do
      expect(subject).to_not eq double
    end

    it 'should be equal if all attributes are equal' do
      expect(subject).to eq comparison_object
    end

    it 'should be equal if the time is equal in string representation' do
      subject.updated_at = timestamp_with_nsecs
      comparison_object.updated_at = timestamp_without_nsecs

      expect(subject).to eq comparison_object
    end

    it 'should alias `eql?` to `==`' do
      expect(subject).to eql comparison_object
    end
  end
end
