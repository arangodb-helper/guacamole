# -*- encoding : utf-8 -*-

require 'spec_helper'
require 'guacamole/collection'

class Test
end

class TestCollection
  include Guacamole::Collection
end

describe Guacamole::Collection do
  let(:callbacks) { double('Callback') }
  let(:callbacks_module) { double('CallbacksModule') }

  subject { TestCollection }

  before do
    allow(callbacks_module).to receive(:callbacks_for).and_return(callbacks)
    allow(callbacks).to receive(:run_callbacks).with(:save, :create).and_yield
    allow(callbacks).to receive(:run_callbacks).with(:save, :update).and_yield
    allow(callbacks).to receive(:run_callbacks).with(:delete).and_yield
    stub_const('Guacamole::Callbacks', callbacks_module)
  end

  describe 'Configuration' do
    it 'should set the connection to the ArangoDB collection' do
      mock_collection_connection = double('ConnectionToCollection')
      subject.connection         = mock_collection_connection

      expect(subject.connection).to eq mock_collection_connection
    end

    it 'should set the Mapper instance to map documents to models and vice versa' do
      mock_mapper    = double('Mapper')
      subject.mapper = mock_mapper

      expect(subject.mapper).to eq mock_mapper
    end

    it 'should set the connection to ArangoDB' do
      mock_db          = double('Ashikawa::Core::Database')
      subject.database = mock_db

      expect(subject.database).to eq mock_db
    end

    it 'should know the name of the collection in ArangoDB' do
      expect(subject.collection_name).to eq 'test'
    end

    it 'should know the class of the model to manage' do
      expect(subject.model_class).to eq Test
    end
  end

  describe 'database' do
    before do
      subject.database = nil
    end

    it 'should default to Guacamole.configuration.database' do
      default_database = double('Database')
      configuration    = double('Configuration', database: default_database)
      allow(Guacamole).to receive(:configuration).and_return(configuration)

      expect(subject.database).to eq default_database
    end
  end

  describe 'connection' do
    before do
      subject.connection = nil
    end

    it 'should default to the collection "collection_name" in the database' do
      database = double('Database')
      allow(subject).to receive(:database).and_return(database)

      expect(database).to receive(:[]).with(subject.collection_name)

      subject.connection
    end
  end

  describe 'mapper' do
    before do
      subject.mapper = nil
    end

    it 'should default to Guacamole.configuration.default_mapper' do
      default_mapper  = double('Mapper')
      mapper_instance = double('MapperInstance')
      configuration   = double('Configuration', default_mapper: default_mapper)
      allow(Guacamole).to receive(:configuration).and_return(configuration)
      allow(default_mapper).to receive(:new).with(subject.model_class).and_return(mapper_instance)

      expect(subject.mapper).to eq mapper_instance
    end
  end

  let(:connection) { double('Connection') }
  let(:mapper)     { double('Mapper') }

  before do
    subject.connection = connection
    subject.mapper     = mapper
  end

  describe 'by_key' do
    it 'should get mapped documents by key from the database' do
      document           = { data: 'foo' }
      model              = double('Model')

      expect(connection).to receive(:fetch).with('some_key').and_return(document)
      expect(mapper).to receive(:document_to_model).with(document).and_return(model)

      expect(subject.by_key('some_key')).to eq model
    end

    it 'should raise a Ashikawa::Core::DocumentNotFoundException exception for nil' do
      expect { subject.by_key(nil) }.to raise_error(Ashikawa::Core::DocumentNotFoundException)
    end
  end

  describe 'save' do

    before do
      allow(mapper).to receive(:model_to_document).with(model).and_return(document)
      allow(mapper).to receive(:referenced_by_models).and_return([])
      allow(mapper).to receive(:referenced_models).and_return([])
    end

    let(:key)       { double('Key') }
    let(:rev)       { double('Rev') }
    let(:document)  { double('Document', key: key, revision: rev).as_null_object }
    let(:model)     { double('Model').as_null_object }
    let(:response)  { double('Hash') }

    context 'a valid model' do

      before do
        allow(model).to receive(:valid?).and_return(true)
        allow(connection).to receive(:create_document).with(document).and_return(document)
        allow(model).to receive(:persisted?).and_return(false)
      end

      it 'should run the save callbacks for the given model' do
        expect(subject).to receive(:callbacks).with(model).and_return(callbacks)

        subject.save model
      end

      context 'which is not persisted' do
        it 'should return the model after calling save' do
          expect(subject.save(model)).to eq model
        end

        it 'should add key to model' do
          expect(model).to receive(:key=).with(key)

          subject.save model
        end

        it 'should add rev to model' do
          expect(model).to receive(:rev=).with(rev)

          subject.save model
        end
      end

      context 'which is persisted' do

        before do
          allow(model).to receive(:persisted?).and_return(true)
          allow(connection).to receive(:replace).and_return(response)
          allow(response).to receive(:[]).with('_rev').and_return(rev)
        end

        let(:model)    { double('Model', key: key).as_null_object }

        it 'should update the document by key via the connection' do
          expect(connection).to receive(:replace).with(key, document)

          subject.save model
        end

        it 'should update the revision after replacing the document' do
          allow(connection).to receive(:replace).and_return(response).ordered
          expect(model).to receive(:rev=).with(rev).ordered

          subject.save model
        end

        it 'should return the model' do
          expect(subject.save(model)).to eq model
        end

        it 'should not update created_at' do
          expect(model).not_to receive(:created_at=)

          subject.save model
        end

      end
    end

    context 'an invalid model' do

      before do
        expect(model).to receive(:valid?).and_return(false)
      end

      context 'which is not persisted' do

        before do
          allow(model).to receive(:persisted?).and_return(false)
        end

        it 'should not be used to create the document' do
          expect(connection).not_to receive(:create_document)

          subject.save model
        end

        it 'should not be changed' do
          expect(model).not_to receive(:key=)
          expect(model).not_to receive(:rev=)

          subject.save model
        end

        it 'should return false' do
          expect(subject.save(model)).to be false
        end
      end

      context 'which is persisted' do

        before do
          allow(model).to receive(:persisted?).and_return(true)
          allow(response).to receive(:[]).with('_rev').and_return(rev)
        end

        let(:model)    { double('Model', key: key).as_null_object }

        it 'should not be used to update the document' do
          expect(connection).not_to receive(:replace)

          subject.save model
        end

        it 'should not be changed' do
          expect(model).not_to receive(:rev=)
          expect(model).not_to receive(:updated_at=)

          subject.save model
        end

        it 'should return false' do
          expect(subject.save(model)).to be false
        end
      end
    end
  end

  describe 'create' do

    before do
      allow(connection).to receive(:create_document).with(document).and_return(document)
      allow(mapper).to receive(:model_to_document).with(model).and_return(document)
      allow(mapper).to receive(:referenced_by_models).and_return([])
      allow(mapper).to receive(:referenced_models).and_return([])
    end

    let(:key)       { double('Key') }
    let(:rev)       { double('Rev') }
    let(:document)  { double('Document', key: key, revision: rev).as_null_object }
    let(:model)     { double('Model').as_null_object }

    context 'a valid model' do
      before do
        allow(model).to receive(:valid?).and_return(true)
      end

      it 'should create a document' do
        expect(connection).to receive(:create_document).with(document).and_return(document)
        expect(mapper).to receive(:model_to_document).with(model).and_return(document)

        subject.create model
      end

      it 'should return the model after calling create' do
        expect(subject.create(model)).to eq model
      end

      it 'should add key to model' do
        expect(model).to receive(:key=).with(key)

        subject.create model
      end

      it 'should add rev to model' do
        expect(model).to receive(:rev=).with(rev)

        subject.create model
      end

      it 'should run the create callbacks for the given model' do
        expect(callbacks).to receive(:run_callbacks).with(:save, :create).and_yield

        subject.create model
      end

      it 'should run first the validation and then the create callbacks' do
        expect(model).to receive(:valid?).ordered.and_return(true)
        expect(callbacks).to receive(:run_callbacks).ordered.with(:save, :create).and_yield

        subject.create model
      end

      context 'with referenced model' do
        let(:referenced_model)                { double('ReferencedModel') }
        let(:referenced_model_name)           { :some_referenced_model }
        let(:referenced_models)               { [referenced_model_name] }
        let(:collection_for_referenced_model) { double('Collection') }

        before do
          allow(referenced_model).to receive(:persisted?).and_return(false)
          allow(mapper).to receive(:collection_for)
            .with(referenced_model_name)
            .and_return(collection_for_referenced_model)
          allow(mapper).to receive(:referenced_models).and_return(referenced_models)
          allow(model).to receive(:send).with(referenced_model_name).and_return(referenced_model)
          allow(collection_for_referenced_model).to receive(:save).with(referenced_model)
        end

        it 'should save each referenced model' do
          expect(collection_for_referenced_model).to receive(:save).with(referenced_model)

          subject.create model
        end

        it 'should save the reference only if it is not already persisted' do
          allow(referenced_model).to receive(:persisted?).and_return(true)
          expect(collection_for_referenced_model).not_to receive(:save).with(referenced_model)

          subject.create model
        end

        it 'should save the reference only if it is present' do
          allow(model).to receive(:send).with(:some_referenced_model).and_return(nil)
          expect(collection_for_referenced_model).not_to receive(:save).with(referenced_model)

          subject.create model
        end
      end

      context 'with referenced_by model' do
        let(:referenced_by_model)                { double('ReferencedByModel') }
        let(:referenced_by_model_name)           { :some_referenced_by_model }
        let(:referenced_by_models)               { [referenced_by_model_name] }
        let(:collection_for_referenced_by_model) { double('Collection') }

        before do
          allow(referenced_by_model).to receive(:persisted?).and_return(false)
          allow(referenced_by_model).to receive("#{model.class.name.demodulize.underscore}=").with(model)
          allow(mapper).to receive(:collection_for)
            .with(referenced_by_model_name)
            .and_return(collection_for_referenced_by_model)
          allow(mapper).to receive(:referenced_by_models).and_return(referenced_by_models)
          allow(model).to receive(:send).with(referenced_by_model_name).and_return([referenced_by_model])
          allow(collection_for_referenced_by_model).to receive(:save).with(referenced_by_model)
        end

        it 'should save the references' do
          expect(collection_for_referenced_by_model).to receive(:save).with(referenced_by_model)

          subject.create model
        end

        it 'should save the references only if it is not already persisted' do
          allow(referenced_by_model).to receive(:persisted?).and_return(true)
          expect(collection_for_referenced_by_model).not_to receive(:save).with(referenced_by_model)

          subject.create model
        end

        it 'should save the references only if it is present' do
          allow(model).to receive(:send).with(referenced_by_model_name).and_return([])
          expect(collection_for_referenced_by_model).not_to receive(:save).with(referenced_by_model)

          subject.create model
        end

        it 'should ensure the references have the parent model assigned prior saving' do
          expect(referenced_by_model).to receive("#{model.class.name.demodulize.underscore}=").with(model).ordered
          expect(collection_for_referenced_by_model).to receive(:save).with(referenced_by_model).ordered

          subject.create model
        end
      end
    end

    context 'an invalid model' do

      before do
        expect(model).to receive(:valid?).and_return(false)
      end

      it 'should not be used to create the document' do
        expect(connection).not_to receive(:create_document)

        subject.create model
      end

      it 'should not be changed' do
        expect(model).not_to receive(:key=)
        expect(model).not_to receive(:rev=)

        subject.create model
      end

      it 'should return false' do
        expect(subject.create(model)).to be false
      end
    end
  end

  describe 'delete' do
    let(:document) { double('Document') }
    let(:key)      { double('Key') }
    let(:model)    { double('Model', key: key) }

    before do
      allow(connection).to receive(:fetch).with(key).and_return(document)
      allow(subject).to receive(:by_key)
      allow(document).to receive(:delete)
    end

    context 'a key was provided' do
      before do
        allow(mapper).to receive(:document_to_model).with(document).and_return(model)
      end

      it 'should load the document and instantiate the model' do
        expect(mapper).to receive(:document_to_model).with(document).and_return(model)

        subject.delete key
      end

      it 'should delete the according document' do
        expect(document).to receive(:delete)

        subject.delete key
      end

      it 'should return the according key' do
        expect(subject.delete(key)).to eq key
      end

      it 'should run the delete callbacks for the given model' do
        expect(subject).to receive(:callbacks).with(model).and_return(callbacks)
        expect(callbacks).to receive(:run_callbacks).with(:delete).and_yield

        subject.delete model
      end
    end

    context 'a model was provided' do
      it 'should delete the according document' do
        expect(document).to receive(:delete)

        subject.delete model
      end

      it 'should return the according key' do
        expect(subject.delete(model)).to eq key
      end

      it 'should run the delete callbacks for the given model' do
        expect(subject).to receive(:callbacks).with(model).and_return(callbacks)
        expect(callbacks).to receive(:run_callbacks).with(:delete).and_yield

        subject.delete model
      end
    end
  end

  describe 'update' do
    let(:key)      { double('Key') }
    let(:rev)      { double('Rev') }
    let(:model)    { double('Model', key: key).as_null_object }
    let(:document) { double('Document').as_null_object }
    let(:response) { double('Hash') }

    before do
      allow(mapper).to receive(:model_to_document).with(model).and_return(document)
      allow(connection).to receive(:replace).and_return(response)
      allow(response).to receive(:[]).with('_rev').and_return(rev)
    end

    context 'a valid model' do
      before do
        allow(model).to receive(:valid?).and_return(true)
      end

      it 'should update the document by key via the connection' do
        expect(connection).to receive(:replace).with(key, document)

        subject.update model
      end

      it 'should update the revision after replacing the document' do
        allow(connection).to receive(:replace).and_return(response).ordered
        expect(model).to receive(:rev=).with(rev).ordered

        subject.update model
      end

      it 'should return the model' do
        expect(subject.update(model)).to eq model
      end

      it 'should run the update callbacks for the given model' do
        expect(callbacks).to receive(:run_callbacks).with(:save, :update).and_yield

        subject.update model
      end

      it 'should run first the validation and then the update callbacks' do
        expect(model).to receive(:valid?).ordered.and_return(true)
        expect(callbacks).to receive(:run_callbacks).ordered.with(:save, :update).and_yield

        subject.update model
      end
    end

    context 'an invalid model' do
      before do
        allow(model).to receive(:valid?).and_return(false)
      end

      it 'should not be used to update the document' do
        expect(connection).not_to receive(:replace)

        subject.update model
      end

      it 'should not be changed' do
        expect(model).not_to receive(:rev=)

        subject.update model
      end

      it 'should return false' do
        expect(subject.update(model)).to be false
      end
    end
  end

  describe 'by_example' do
    let(:example) { double }
    let(:query_connection) { double }
    let(:query) { double }

    before do
      allow(connection).to receive(:query)
        .and_return(query_connection)

      allow(Guacamole::Query).to receive(:new)
        .and_return(query)

      allow(query).to receive(:example=)
    end

    it 'should create a new query with the query connection and mapper' do
      expect(Guacamole::Query).to receive(:new)
        .with(query_connection, mapper)

      subject.by_example(example)
    end

    it 'should set the example for the query' do
      expect(query).to receive(:example=)
        .with(example)

      subject.by_example(example)
    end

    it 'should return the query' do
      expect(subject.by_example(example)).to be query
    end
  end

  describe 'all' do
    let(:query_connection) { double }
    let(:query) { double }

    before do
      allow(connection).to receive(:query)
        .and_return(query_connection)

      allow(Guacamole::Query).to receive(:new)
        .and_return(query)
    end

    it 'should create a new query with the query connection and mapper' do
      expect(Guacamole::Query).to receive(:new)
        .with(query_connection, mapper)

      subject.all
    end

    it 'should return the query' do
      expect(subject.all).to be query
    end
  end

  describe 'map' do
    let(:mapper) { double('Mapper') }

    before do
      subject.mapper = mapper
    end

    it 'should evaluate the block on the mapper instance' do
      expect(mapper).to receive(:method_to_call_on_mapper)

      subject.map do
        method_to_call_on_mapper
      end
    end
  end

  describe 'index' do
    let(:mock_index) { double('Index') }

    it 'creates a hash index on the given attributes' do
      params = { on: 'attribute1' }
      allow(subject.connection).to receive(:add_index).with(:hash, params).and_return(mock_index)

      expect(subject.index(:hash, params)).to eq mock_index
    end
  end

  describe 'handle_client_error' do
    let(:model)     { double('Model').as_null_object }

    before { allow(model).to receive(:persisted?).and_return false }

    it 'should add not raise the error if code was found' do
      error = Ashikawa::Core::ClientError.new(
        '1210: cannot create document, unique constraint violated'
      )
      allow(subject).to receive(:create).with(model).and_raise error

      expect { subject.save(model) }.not_to raise_error
    end

    it 'should add raise the error if code is not found' do
      error = Ashikawa::Core::ClientError.new(
        "-1: The error is that you can't handle this code"
      )
      allow(subject).to receive(:create).with(model).and_raise error

      expect { subject.save(model) }.to raise_error(error)
    end
  end

  describe 'callbacks' do
    let(:model) { double('Model') }

    it 'should get the callback instance for the given model' do
      expect(callbacks_module).to receive(:callbacks_for).with(model)

      subject.callbacks model
    end
  end
end
