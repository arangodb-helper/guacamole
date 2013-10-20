# -*- encoding : utf-8 -*-
require 'guacamole'
require 'acceptance/spec_helper'

class Article
  include Guacamole::Model

  attribute :title, String

  validates :title, presence: true
end

class ArticlesCollection
  include Guacamole::Collection
end

describe 'ModelBasics' do

  describe Article do
    it 'should allow setting its title' do
      subject.title = 'This is my fancy article'

      expect(subject.title).to eq('This is my fancy article')
    end

    it 'should have key and rev attributes' do
      expect(subject.key).to be_nil
      expect(subject.rev).to be_nil
    end

    it 'should have timestamp attributes which are empty' do
      expect(subject.created_at).to be_nil
      expect(subject.updated_at).to be_nil
    end

    it 'should validate its attributes' do
      expect(subject.valid?).to be_false
      subject.title = 'The Legend of Zelda'
      expect(subject.valid?).to be_true
    end

    it 'should know its model name' do
      # This test passes when you only require ActiveModel::Validations
      expect(subject.class.model_name).to eq 'Article'
    end

    it 'should convert itself to params' do
      subject.key = 'random_number'
      expect(subject.to_param).to eq 'random_number'
    end
  end

end

describe 'CollectionBasics' do

  describe ArticlesCollection do
    subject { ArticlesCollection }

    let(:some_article) { Fabricate(:article) }

    it 'should provide a method to find documents by key and return the appropriate model' do
      found_model = subject.by_key some_article.key
      expect(found_model).to eq some_article
    end

    it 'should save models to the database' do
      new_article = Fabricate.build(:article)
      subject.save new_article

      expect(subject.by_key(new_article.key)).to eq new_article
    end

    it 'should update models in the database' do
      some_article.title = 'Has been updated'
      subject.replace some_article

      updated_article = subject.by_key(some_article.key)

      expect(updated_article.title).to eq 'Has been updated'
    end

    it 'should receive all documents by title' do
      subject.save Fabricate.build(:article, title: 'Disturbed')
      subject.save Fabricate.build(:article, title: 'Not so Disturbed')

      result = subject.by_example(title: 'Disturbed').first

      expect(result.title).to eq 'Disturbed'
    end
  end

end
