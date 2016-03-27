# -*- encoding : utf-8 -*-

require 'spec_helper'
require 'guacamole/transaction'
require 'guacamole/model'

describe Guacamole::Transaction::Vertex do
  let(:model) { instance_double('Model') }
  let(:model_object_id) { double('ObjectId') }
  let(:model_key) { double('Key') }
  let(:model_id) { double('Id') }
  let(:collection) { double('Collection') }
  let(:document) { double('Document') }

  subject { Guacamole::Transaction::Vertex.new(model, collection, document) }

  before do
    allow(model).to receive(:object_id).and_return(model_object_id)
    allow(model).to receive(:key).and_return(model_key)
    allow(model).to receive(:arangodb_id).and_return(model_id)
  end

  its(:key) { should eq model_key }
  its(:id) { should eq model_id }

  context 'with new vertex' do
    let(:model_id) { nil }

    its(:id_for_edge) { should eq model_object_id }
  end

  context 'with existing vertex' do
    its(:id_for_edge) { should eq model_id }
  end

  it 'should return a hash to be used in the transaction code' do
    vertex_hash = {
      object_id: model_object_id,
      collection: collection,
      document: document,
      _key: model_key,
      _id: model.arangodb_id
    }

    expect(subject.as_json).to eq vertex_hash
  end
end

describe Guacamole::Transaction::TargetStatesBuilder do
  let(:model) { instance_double('Model') }
  let(:mapper) { double('Mapper') }
  let(:collection) { double('Collection') }
  let(:edge_attributes) { [] }

  subject { Guacamole::Transaction::TargetStatesBuilder }

  before do
    allow(mapper).to receive(:edge_attributes).and_return(edge_attributes)
    allow(collection).to receive(:mapper).and_return(mapper)
  end

  describe 'build concrete TargetState instances' do
    it 'should always return an array of TargetState instances' do
      expect(subject.build(model, collection)).to be_an Array
    end

    context 'with edge attributes' do
      let(:this_edge_attribute) { double('EdgeAttribute') }
      let(:that_edge_attribute) { double('EdgeAttribute') }
      let(:edge_attributes) { [this_edge_attribute, that_edge_attribute] }

      it 'should create a TargetState instance for every edge attribute of the model' do
        expect(Guacamole::Transaction::SubGraphTargetState).to receive(:new).with(model, this_edge_attribute)
        expect(Guacamole::Transaction::SubGraphTargetState).to receive(:new).with(model, that_edge_attribute)

        subject.build(model, collection)
      end
    end

    context 'without edge attributes' do
      it 'should build a VertexTargetState instance' do
        expect(Guacamole::Transaction::VertexTargetState).to receive(:new).with(model, collection)

        subject.build(model, collection)
      end
    end
  end
end

describe Guacamole::Transaction::VertexTargetState do
  let(:model) { instance_double('Model') }
  let(:collection) { double('Collection') }
  let(:collection_name) { double('CollectionName') }
  let(:document) { double('Document') }
  let(:mapper) { double('Mapper') }
  let(:vertex) { double('Vertex') }

  subject { Guacamole::Transaction::VertexTargetState.new(model, collection) }

  before do
    allow(collection).to receive(:collection_name).and_return(collection_name)
    allow(collection).to receive(:mapper).and_return(mapper)
    allow(mapper).to receive(:model_to_document).with(model).and_return(document)
    allow(Guacamole::Transaction::Vertex).to receive(:new).with(model, collection_name, document).and_return(vertex)
  end

  its(:edge_collection_name) { should be_nil }
  its(:to_vertices) { should eq [] }
  its(:from_vertices) { should eq [vertex] }

  it 'should have a reasonable JSON representation' do
    from_vertices_as_json = double('FromVerticesAsJSON')
    allow(subject).to receive(:from_vertices).and_return(from_vertices = double)
    allow(from_vertices).to receive(:as_json).and_return(from_vertices_as_json)

    expect(subject.as_json).to eq(name: nil,
                                  fromVertices: from_vertices_as_json,
                                  toVertices: [], edges: [], oldEdges: [])
  end
end

describe Guacamole::Transaction::SubGraphTargetState do
  let(:model) { instance_double('Model') }
  let(:model_id) { double('ModelId') }
  let(:from_model_class) { double('FromModelClass') }
  let(:to_model_class) { double('ToModelClass') }

  let(:from_collection) { double('Collection') }
  let(:from_collection_name) { double('FromCollectionName') }

  let(:to_collection) { double('Collection') }
  let(:to_collection_name) { double('ToCollectionName') }

  let(:edge_attribute) { double('EdgeAttribute') }
  let(:edge_class) { double('EdgeClass') }
  let(:edge_collection_class) { double('EdgeCollectionClass') }
  let(:edge_collection) { double('EdgeCollection') }
  let(:edge_collection_name) { double('EdgeCollectionName') }

  let(:from_document) { double('FromDocument') }
  let(:to_document) { double('ToDocument') }

  subject { Guacamole::Transaction::SubGraphTargetState.new(model, edge_attribute) }

  before do
    stub_const('Guacamole::EdgeCollection', edge_collection_class)

    allow(model).to receive(:arangodb_id).and_return(model_id)

    allow(edge_class).to receive(:from_collection).and_return(from_collection)
    allow(from_collection).to receive(:model_class).and_return(from_model_class)
    allow(from_collection).to receive(:collection_name).and_return(from_collection_name)

    allow(edge_class).to receive(:to_collection).and_return(to_collection)
    allow(to_collection).to receive(:model_class).and_return(to_model_class)
    allow(to_collection).to receive(:collection_name).and_return(to_collection_name)

    allow(edge_attribute).to receive(:edge_class).and_return(edge_class)
    allow(edge_collection_class).to receive(:for).and_return(edge_collection)
    allow(edge_collection).to receive(:collection_name).and_return(edge_collection_name)
  end

  its(:start_model) { should eq model }
  its(:edge_attribute) { should eq edge_attribute }
  its(:edge_collection) { should eq edge_collection }
  its(:edge_collection_name) { should eq edge_collection_name }
  its(:edge_class) { should eq edge_class }

  context "Array edge attribute" do
    before do
      allow(edge_attribute).to receive(:type).with(any_args).and_return(Virtus::Attribute::Collection::Type.new(to_model_class))
    end

    it 'should have a representation suitable for JSON serialization' do
      from_vertices = double('FromVertices')
      to_vertices   = double('ToVertices')

      allow(subject).to receive(:from_vertices).and_return(double(as_json: from_vertices))
      allow(subject).to receive(:to_vertices).and_return(double(as_json: to_vertices))
      allow(subject).to receive(:edges).and_return(edges = double)
      allow(subject).to receive(:old_edge_keys).and_return(old_edge_keys = double)

      state_as_json = {
        name: edge_collection_name,
        fromVertices: from_vertices,
        toVertices: to_vertices,
        edges: edges,
        oldEdges: old_edge_keys
      }

      expect(subject.as_json).to eq state_as_json
    end

    it 'should select the responsible mapper for a given model' do
      expect(edge_collection).to receive(:mapper_for_start).with(model)

      subject.mapper_for_model(model)
    end

    it 'should map the given model to a document' do
      mapper = double('Mapper')
      allow(subject).to receive(:mapper_for_model).with(model).and_return(mapper)
      expect(mapper).to receive(:model_to_document).with(model)

      subject.model_to_document(model)
    end

    it 'should get a single related model of the edge_attribute as array' do
      allow(edge_attribute).to receive(:type).with(any_args).and_return(:Model)
      related_model = instance_double('Model')
      allow(edge_attribute).to receive(:get_value).with(model).and_return(related_model)
      expect(subject.related_models).to eq [Guacamole::Transaction::SubGraphTargetState::ModelWithAttributes.new(related_model, {})]
    end

    it 'should get multiple related models of the edge_attribute as array' do
      related_model1 = instance_double('Model')
      related_model2 = instance_double('Model')
      allow(edge_attribute).to receive(:get_value).with(model).and_return([related_model1, related_model2])

      expect(subject.related_models).to eq [
        Guacamole::Transaction::SubGraphTargetState::ModelWithAttributes.new(related_model1, {}),
        Guacamole::Transaction::SubGraphTargetState::ModelWithAttributes.new(related_model2, {})]
    end

    describe 'building of edges' do
      let(:from_vertex1) { double('Vertex', id_for_edge: '42') }
      let(:from_vertex2) { double('Vertex', id_for_edge: '23') }
      let(:to_vertex) { double('Vertex', id_for_edge: '101', edge_attributes: {}) }

      before do
        allow(subject).to receive(:from_vertices).and_return([from_vertex1, from_vertex2])
        allow(subject).to receive(:to_vertices).and_return([to_vertex])
      end

      it 'should build a list of edges to connect all from vertices to the to vertices' do
        pattern = [
          {
            _from: from_vertex1.id_for_edge,
            _to: to_vertex.id_for_edge
          }.ignore_extra_keys!,
          {
            _from: from_vertex2.id_for_edge,
            _to: to_vertex.id_for_edge
          }.ignore_extra_keys!
        ]

        expect(subject.edges).to match_json_expression(pattern)
      end

      it 'should have a list of edges all with empty attributes' do
        expect(subject.edges).to all(include(attributes: {}))
      end
    end

    describe 'building of vertices' do
      let(:from_vertex) { double('Vertex') }
      let(:to_vertex) { double('Vertex', edge_attributes: {}) }
      let(:query_result) { double('Query') }

      before do
        allow(query_result).to receive(:key)
        allow(query_result).to receive(:map).and_yield(query_result)

        allow(subject).to receive(:model_to_document).with(from_model).and_return(from_document)
        allow(subject).to receive(:model_to_document).with(to_model).and_return(to_document)

        allow(Guacamole::Transaction::Vertex).to receive(:new).
          with(from_model, from_collection_name, from_document, nil).
          and_return(from_vertex)
        allow(Guacamole::Transaction::Vertex).to receive(:new).
          with(to_model, to_collection_name, to_document, {}).
          and_return(to_vertex)
      end

      context 'model is the :from part of the edge' do
        let(:from_model) { model }
        let(:to_model) { double('ToModel') }

        before do
          allow(from_model_class).to receive(:===).with(model).and_return(true)
          allow(to_model_class).to receive(:===).with(model).and_return(false)
          allow(subject).to receive(:related_models).and_return(
            [Guacamole::Transaction::SubGraphTargetState::ModelWithAttributes.new(
              to_model, {})
            ])
        end

        it 'should transform model to the :from vertices' do
          allow(Guacamole::Transaction::Vertex).to receive(:new).
            with(from_model, from_collection_name, from_document, {}).
            and_return(from_vertex)

          expect(subject.from_vertices).to eq [from_vertex]
        end

        it 'should transform the related models to :to vertices' do
          expect(subject.to_vertices).to eq [to_vertex]
        end

        it 'should select the old edge keys based on :from for the model' do
          expect(edge_collection).to receive(:by_example).with(_from: model_id).and_return(query_result)

          subject.old_edge_keys
        end
      end

      context 'model is the :to part of the edge' do
        let(:from_model) { double('FromModel') }
        let(:to_model) { model }

        before do
          allow(from_model_class).to receive(:===).with(model).and_return(false)
          allow(to_model_class).to receive(:===).with(model).and_return(true)
          allow(subject).to receive(:related_models).and_return(
            [Guacamole::Transaction::SubGraphTargetState::ModelWithAttributes.new(from_model,{})])
        end

        it 'should transform model to the :to vertices' do
          expect(subject.to_vertices).to eq [to_vertex]
        end

        it 'should transform the related models to :from vertices' do
          allow(Guacamole::Transaction::Vertex).to receive(:new).
            with(from_model, from_collection_name, from_document, {}).
            and_return(from_vertex)

          expect(subject.from_vertices).to eq [from_vertex]
        end

        it 'should select the old edges based on :to for the model' do
          expect(edge_collection).to receive(:by_example).with(_to: model_id).and_return(query_result)

          subject.old_edge_keys
        end
      end
    end
  end

  context "Hash edge attribute" do
    before do
      allow(edge_attribute).to receive(:type).with(any_args).and_return(Virtus::Attribute::Hash::Type.new(String, to_model_class))
    end

    it 'should have a representation suitable for JSON serialization' do
      from_vertices = double('FromVertices')
      to_vertices   = double('ToVertices')

      allow(subject).to receive(:from_vertices).and_return(double(as_json: from_vertices))
      allow(subject).to receive(:to_vertices).and_return(double(as_json: to_vertices))
      allow(subject).to receive(:edges).and_return(edges = double)
      allow(subject).to receive(:old_edge_keys).and_return(old_edge_keys = double)

      state_as_json = {
        name: edge_collection_name,
        fromVertices: from_vertices,
        toVertices: to_vertices,
        edges: edges,
        oldEdges: old_edge_keys
      }

      expect(subject.as_json).to eq state_as_json
    end

    it 'should select the responsible mapper for a given model' do
      expect(edge_collection).to receive(:mapper_for_start).with(model)

      subject.mapper_for_model(model)
    end

    it 'should map the given model to a document' do
      mapper = double('Mapper')
      allow(subject).to receive(:mapper_for_model).with(model).and_return(mapper)
      expect(mapper).to receive(:model_to_document).with(model)

      subject.model_to_document(model)
    end

    it 'should get an empty related model of the edge_attribute as array' do
      related_model = instance_double('Model')
      allow(edge_attribute).to receive(:get_value).with(model).and_return( {} )

      expect(subject.related_models).to eql []
    end

    it 'should get a single related model of the edge_attribute as array' do
      related_model = instance_double('Model')
      allow(edge_attribute).to receive(:get_value).with(model).and_return( { key: related_model } )

      expect(subject.related_models).to eql [Guacamole::Transaction::SubGraphTargetState::ModelWithAttributes.new(related_model, {hash_key: :key}) ]
    end

    it 'should get multiple related models of the edge_attribute as array' do
      related_model1 = instance_double('Model')
      related_model2 = instance_double('Model')
      allow(edge_attribute).to receive(:get_value).with(model).and_return( { key: related_model1, other_key: related_model2 } )

      expect(subject.related_models).to eql [
        Guacamole::Transaction::SubGraphTargetState::ModelWithAttributes.new(
          related_model1, { hash_key: :key }),
        Guacamole::Transaction::SubGraphTargetState::ModelWithAttributes.new(
          related_model2, { hash_key: :other_key })
      ]
    end

    describe 'building of edges' do
      let(:from_vertex1) { double('Vertex', id_for_edge: '42') }
      let(:from_vertex2) { double('Vertex', id_for_edge: '23') }
      let(:to_vertex) { double('Vertex', id_for_edge: '101', edge_attributes: { hash_key: "name" }) }

      before do
        allow(subject).to receive(:from_vertices).and_return([from_vertex1, from_vertex2])
        allow(subject).to receive(:to_vertices).and_return([to_vertex])
      end

      it 'should build a list of edges to connect all from vertices to the to vertices' do
        pattern = [
          {
            _from: from_vertex1.id_for_edge,
            _to: to_vertex.id_for_edge,
            attributes: {
              hash_key: "name"
            }
          }.ignore_extra_keys!,
          {
            _from: from_vertex2.id_for_edge,
            _to: to_vertex.id_for_edge,
            attributes: {
              hash_key: "name"
            }
          }.ignore_extra_keys!
        ]

        expect(subject.edges).to match_json_expression(pattern)
      end

      it 'should have a list of edges all with attributes' do
        expect(subject.edges).to all(include(attributes: {hash_key: "name"}))
      end
    end

    describe 'building of vertices' do
      let(:from_vertex) { double('Vertex') }
      let(:to_vertex) { double('Vertex', { hash_key: "foo" }) }
      let(:query_result) { double('Query') }

      before do
        allow(query_result).to receive(:key)
        allow(query_result).to receive(:map).and_yield(query_result)

        allow(subject).to receive(:model_to_document).with(from_model).and_return(from_document)
        allow(subject).to receive(:model_to_document).with(to_model).and_return(to_document)

        allow(Guacamole::Transaction::Vertex).to receive(:new).
          with(to_model, to_collection_name, to_document, {"hash_key" => "foo"}).
          and_return(to_vertex)
      end

      context 'model is the :from part of the edge' do
        let(:from_model) { model }
        let(:to_model) { double('ToModel') }

        before do
          allow(from_model_class).to receive(:===).with(model).and_return(true)
          allow(to_model_class).to receive(:===).with(model).and_return(false)
          allow(subject).to receive(:related_models).and_return([Guacamole::Transaction::SubGraphTargetState::ModelWithAttributes.new(to_model,{"hash_key" => "foo"})])
        end

        it 'should transform model to the :from vertices' do
          allow(Guacamole::Transaction::Vertex).to receive(:new).
            with(from_model, from_collection_name, from_document, {}).
            and_return(from_vertex)
          expect(subject.from_vertices).to eq [from_vertex]
        end

        it 'should transform the related models to :to vertices' do
          expect(subject.to_vertices).to eq [to_vertex]
        end

        it 'should select the old edge keys based on :from for the model' do
          expect(edge_collection).to receive(:by_example).with(_from: model_id).and_return(query_result)

          subject.old_edge_keys
        end
      end

      context 'model is the :to part of the edge' do
        let(:from_model) { double('FromModel') }
        let(:to_model) { model }

        before do
          allow(from_model_class).to receive(:===).with(model).and_return(false)
          allow(to_model_class).to receive(:===).with(model).and_return(true)
          allow(subject).to receive(:related_models).and_return(
            [Guacamole::Transaction::SubGraphTargetState::ModelWithAttributes.new(
              from_model, {hash_key: 'foo'})
            ])
#          allow(Guacamole::Transaction::Vertex).to receive(:new).
#            with(to_model, from_collection_name, from_document, {}).
#            and_return(from_vertex)
        end

        it 'should transform model to the :to vertices' do
          allow(Guacamole::Transaction::Vertex).to receive(:new).
            with(to_model, to_collection_name, to_document, {}).
            and_return(to_vertex)

          expect(subject.to_vertices).to eq [to_vertex]
        end

        it 'should transform the related models to :from vertices' do
          allow(Guacamole::Transaction::Vertex).to receive(:new).
            with(from_model, from_collection_name, from_document, {hash_key: 'foo'}).
            and_return(from_vertex)

          expect(subject.from_vertices).to eq [from_vertex]
        end

        it 'should select the old edges based on :to for the model' do
          expect(edge_collection).to receive(:by_example).with(_to: model_id).and_return(query_result)

          subject.old_edge_keys
        end
      end
    end
  end
end

describe Guacamole::Transaction do
  let(:collection) { double('Collection') }
  let(:model) { instance_double('Model') }
  let(:database) { double('Database') }
  let(:init_options) { { collection: collection, model: model } }

  subject { Guacamole::Transaction.new(init_options) }

  before do
    allow(collection).to receive(:connection)
    allow(collection).to receive(:database).and_return(database)
  end

  describe '#run' do
    subject { Guacamole::Transaction }

    let(:transaction_instance) { instance_double('Guacamole::Transaction') }

    it 'should build a new transaction and execute it' do
      allow(subject).to receive(:new).with(init_options).and_return(transaction_instance)
      expect(transaction_instance).to receive(:execute_transaction)

      subject.run(init_options)
    end
  end

  describe 'initialization' do
    its(:collection) { should eq collection }
    its(:model)      { should eq model }
    its(:database)   { should eq database }

    it 'should init the connection to the database' do
      expect(collection).to receive(:connection)

      Guacamole::Transaction.new(init_options)
    end
  end

  describe 'edge_collections for the transaction' do
    it 'should pass model and collection to TargetStatesBuilder to create the edge_collections' do
      expect(Guacamole::Transaction::TargetStatesBuilder).to receive(:build).with(model, collection)

      subject.edge_collections
    end
  end

  describe 'determine write and read collections for the transaction' do
    let(:edge_collection) { instance_double('Guacamole::Transaction::SubGraphTargetState') }
    let(:from_vertex) { instance_double('Guacamole::Transaction::Vertex') }
    let(:to_vertex) { instance_double('Guacamole::Transaction::Vertex') }

    let(:edge_collection_name) { double('EdgeCollectionName') }
    let(:from_vertex_collection_name) { double('FromName') }
    let(:to_vertex_collection_name) { double('ToName') }

    before do
      allow(subject).to receive(:edge_collections).and_return([edge_collection])
      allow(edge_collection).to receive(:edge_collection_name).and_return(edge_collection_name)
      allow(edge_collection).to receive(:from_vertices).and_return([from_vertex])
      allow(edge_collection).to receive(:to_vertices).and_return([to_vertex])
      allow(from_vertex).to receive(:collection).and_return(from_vertex_collection_name)
      allow(to_vertex).to receive(:collection).and_return(to_vertex_collection_name)
    end

    it 'should collect all edge_collection and vertex collection names of all target states as write collection' do
      expect(subject.write_collections).to eq [edge_collection_name,
                                               from_vertex_collection_name,
                                               to_vertex_collection_name]
    end

    it 'should have the same read collection as the write collections' do
      expect(subject.read_collections).to eq subject.write_collections
    end
  end

  describe 'send the transaction to the database' do
    let(:graph) { double('Graph', name: 'graph') }
    let(:shared_path) { double('Path') }
    let(:config) { double('Config', graph: graph, shared_path: shared_path) }

    before do
      allow(Guacamole).to receive(:configuration).and_return(config)
    end

    it 'should create the parameters for the transaction' do
      edge_collections = double('EdgeCollections')
      allow(subject).to receive(:edge_collections).and_return(edge_collections)

      expect(subject.transaction_params).to eq(edgeCollections: edge_collections,
                                               graph: graph.name,
                                               log_level: 'debug')
    end

    it 'should prepare the transaction on the database' do
      transaction_code = double('TransactionCode')
      write_collections = double('WriteCollections')
      read_collections = double('ReadCollections')
      allow(subject).to receive(:transaction_code).and_return(transaction_code)
      allow(subject).to receive(:write_collections).and_return(write_collections)
      allow(subject).to receive(:read_collections).and_return(read_collections)

      transaction_options = { write: write_collections, read: read_collections }

      db_transaction = double('DBTransaction')
      allow(database).to receive(:create_transaction).
        with(transaction_code, transaction_options).
        and_return(db_transaction)
      allow(db_transaction).to receive(:wait_for_sync=).with(true)

      subject.transaction
    end

    it 'should load the transaction code' do
      path_to_transaction = double('TransactionCode')
      allow(shared_path).to receive(:join).with('transaction.js').and_return(path_to_transaction)
      expect(File).to receive(:read).with(path_to_transaction)

      subject.transaction_code
    end

    it 'should execute the transaction with the parameters' do
      transaction        = double('DBTransaction')
      transaction_params = double('TransactionParams')

      allow(subject).to receive(:transaction).and_return(transaction)
      allow(subject).to receive(:transaction_params).and_return(transaction_params)
      allow(transaction_params).to receive(:as_json).and_return(transaction_params)
      expect(transaction).to receive(:execute).with(transaction_params)

      subject.execute_transaction
    end
  end
end
