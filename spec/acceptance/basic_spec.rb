# -*- encoding : utf-8 -*-
require 'guacamole'
require 'acceptance/spec_helper'

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
      expect(subject.valid?).to be false
      subject.title = 'The Legend of Zelda'
      expect(subject.valid?).to be true
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

    it 'should create models in the database' do
      new_article = Fabricate.build(:article)
      subject.save new_article

      expect(subject.by_key(new_article.key)).to eq new_article
    end

    it 'should update models in the database' do
      some_article.title = 'Has been updated'
      subject.save some_article

      updated_article = subject.by_key(some_article.key)

      expect(updated_article.title).to eq 'Has been updated'
    end

    it 'should receive all documents by title' do
      subject.save Fabricate.build(:article, title: 'Disturbed')
      subject.save Fabricate.build(:article, title: 'Not so Disturbed')

      result = subject.by_example(title: 'Disturbed').first

      expect(result.title).to eq 'Disturbed'
    end

    context 'delete documents' do
      it 'should delete a document by key' do
        deleted_key = subject.delete(some_article.key)

        expect { subject.by_key(deleted_key) }.to raise_error(Ashikawa::Core::DocumentNotFoundException)
      end

      it 'should delete a document by model' do
        deleted_key = subject.delete(some_article)

        expect { subject.by_key(deleted_key) }.to raise_error(Ashikawa::Core::DocumentNotFoundException)
      end
    end

    it 'should allow to nest models' do
      article_with_comments = Fabricate(:article_with_two_comments)
      found_article = subject.by_key(article_with_comments.key)

      expect(found_article.comments.first).to be_a Comment
      expect(found_article.comments).to eq article_with_comments.comments
    end

    context 'prevent aliasing effects' do
      it 'should hold only one object of the same document when getting one document' do
        this_article = subject.by_key some_article.key
        that_article = subject.by_key some_article.key

        expect(this_article.object_id).to eq that_article.object_id
      end

      it 'should only hold one object of the same document when using `by_example`' do
        Fabricate.times(3, :article)

        subject.all.each do |article|
          expect(article.object_id).to eq subject.by_key(article.key).object_id
        end
      end
    end

    describe 'index' do
      it 'should create a hash index on attributes listed' do
        expect(subject.connection.indices.any? do
          |index| index.type == :hash && index.unique
        end).to eq true
      end

      it 'does not allow two models with the same unique attribute' do
        first_document = Fabricate(:article)
        second_document = Fabricate(:article, unique_attribute: first_document.unique_attribute)
        expect(second_document.errors).to include(:index)
      end

      it 'should raise an exception if geo spatial index value is out of range' do
        document = Fabricate(:article, location: "this is a string and not a location")
        expect(document.errors).to include(:index)
      end
    end
  end

end
