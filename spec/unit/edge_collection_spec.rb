# -*- encoding : utf-8 -*-

require 'spec_helper'
require 'guacamole/edge_collection'

describe Guacamole::EdgeCollection do
  let(:graph)  { double('Graph') }
  let(:graph_name) { double('GraphName') }
  let(:config) { double('Configuration') }

  before do
    allow(Guacamole).to receive(:configuration).and_return(config)
    allow(config).to receive(:graph).and_return(graph)
    allow(graph).to receive(:add_edge_definition)
    allow(graph).to receive(:name).and_return(graph_name)
  end

  context 'the edge collection module' do
    subject { Guacamole::EdgeCollection }

    context 'with user defined edge collection class' do
      let(:edge_class) { double('EdgeClass', name: 'MyEdge') }
      let(:user_defined_edge_collection) { double('EdgeCollection') }

      before do
        stub_const('MyEdgesCollection', user_defined_edge_collection)
        allow(user_defined_edge_collection).to receive(:add_edge_definition_to_graph)
      end

      it 'should return the edge collection for a given edge class' do
        expect(subject.for(edge_class)).to eq user_defined_edge_collection
      end
    end

    context 'without user defined edge collection class' do
      let(:edge_class) { double('EdgeClass', name: 'AmazingEdge') }
      let(:auto_defined_edge_collection) { double('EdgeCollection') }

      before do
        stub_const('ExampleEdge', double('Edge').as_null_object)
        allow(auto_defined_edge_collection).to receive(:add_edge_definition_to_graph)
      end

      it 'should create an edge collection class' do
        edge_collection = subject.create_edge_collection('ExampleEdgesCollection')

        expect(edge_collection.name).to eq 'ExampleEdgesCollection'
        expect(edge_collection.ancestors).to include Guacamole::EdgeCollection
      end

      it 'should return the edge collection for a given edge class' do
        allow(subject).to receive(:create_edge_collection).
                           with('AmazingEdgesCollection').
                           and_return(auto_defined_edge_collection)

        expect(subject.for(edge_class)).to eq auto_defined_edge_collection
      end
    end
  end

  context 'concrete edge collections' do
    subject do
      class SomeEdgesCollection
        include Guacamole::EdgeCollection
      end
    end

    let(:database) { double('Database') }
    let(:edge_collection_name) { 'some_edges' }
    let(:raw_edge_collection) { double('Ashikawa::Core::EdgeCollection') }
    let(:collection_a) { :a }
    let(:collection_b) { :b }
    let(:edge_class) { double('EdgeClass', name: 'SomeEdge', from: collection_a, to: collection_b) }
    let(:model) { double('Model') }

    before do
      stub_const('SomeEdge', edge_class)
      allow(graph).to receive(:edge_collection).with(edge_collection_name).and_return(raw_edge_collection)
      allow(subject).to receive(:database).and_return(database)
      allow(graph).to receive(:add_edge_definition)
    end

    after do
      # This stunt is required to have a fresh subject each time and not running into problems
      # with cached mock doubles that will raise errors upon test execution.
      Object.send(:remove_const, subject.name)
    end

    its(:edge_class) { should eq edge_class }

    it 'should be a specialized Guacamole::Collection' do
      expect(subject).to include Guacamole::Collection
    end

    it 'should map the #connectino to the underlying edge_connection' do
      allow(subject).to receive(:graph).and_return(graph)

      expect(subject.connection).to eq raw_edge_collection
    end

    context 'initialize the edge definition' do
      it 'should add the edge definition as soon as the module is included' do
        just_another_edge_collection = Class.new
        expect(just_another_edge_collection).to receive(:add_edge_definition_to_graph)

        just_another_edge_collection.send(:include, Guacamole::EdgeCollection)
      end

      it 'should create the edge definition based on the edge class' do
        expect(graph).to receive(:add_edge_definition).with(edge_collection_name,
                                                            from: [collection_a], to: [collection_b])

        subject.add_edge_definition_to_graph
      end
    end

    context 'accessing the mapper' do
      let(:collection_a) { double('Collection') }
      let(:collection_b) { double('Collection') }
      let(:mapper_a) { double('DocumentModelMapper') }
      let(:mapper_b)  { double('DocumentModelMapper') }

      before do
        allow(collection_a).to receive(:mapper).and_return(mapper_a)
        allow(collection_b).to receive(:mapper).and_return(mapper_b)
        allow(edge_class).to receive(:from_collection).and_return(collection_a)
        allow(edge_class).to receive(:to_collection).and_return(collection_b)
        allow(mapper_a).to receive(:responsible_for?).with(model).and_return(true)
        allow(mapper_b).to receive(:responsible_for?).with(model).and_return(false)
      end

      it 'should provide a method to get the mapper for the :to collection' do
        expect(subject.mapper_for_target(model)).to eq mapper_b
      end

      it 'should provide a method to get the mapper for the :from collection' do
        expect(subject.mapper_for_start(model)).to eq mapper_a
      end
    end

    context 'getting neighbors' do
      context 'building the bind parameters' do
        let(:model_key) { double('ModelKey') }
        let(:edge_collection_name) { double('CollectionName') }
        let(:direction) { double('Direction') }
        let(:bind_parameters) { subject.build_bind_parameter(model, direction) }

        before do
          allow(model).to receive(:key).and_return(model_key)
          allow(subject).to receive(:collection_name).and_return(edge_collection_name)
        end

        it 'should have the name of the graph' do
          expect(bind_parameters[:graph]).to eq graph_name
        end

        it 'should have the key of the model' do
          expect(bind_parameters[:model_key]).to eq model_key
        end

        it 'should have the name of the edge collection' do
          expect(bind_parameters[:edge_collection]).to eq edge_collection_name
        end

        it 'should have the direction' do
          expect(bind_parameters[:direction]).to eq direction
        end

        it 'should default to :inbound as direction' do
          expect(subject.build_bind_parameter(model)[:direction]).to eq :inbound
        end
      end

      context 'building the actual query object' do
        let(:aql_query) { instance_double('Guacamole::AqlQuery') }
        let(:mapper) { double('Mapper') }
        let(:bind_parameters) { double('BindParameters') }

        before do
          allow(Guacamole::AqlQuery).to receive(:new).and_return(aql_query)
          allow(aql_query).to receive(:aql_fragment=)
          allow(aql_query).to receive(:bind_parameters=)
          allow(subject).to receive(:build_bind_parameter).and_return(bind_parameters)
          allow(subject).to receive(:mapper_for_target).with(model).and_return(mapper)
        end

        it 'should be an AqlQuery' do
          expect(subject.neighbors(model)).to eq aql_query
        end

        it 'should receive an optional direction' do
          direction = double('Direction')
          expect(subject).to receive(:build_bind_parameter).with(model, direction).and_return(bind_parameters)

          subject.neighbors(model, direction)
        end

        it 'should default the direction to :inbound' do
          expect(subject).to receive(:build_bind_parameter).with(model, :inbound).and_return(bind_parameters)

          subject.neighbors(model)
        end

        it 'should set the collection to self' do
          expect(Guacamole::AqlQuery).to receive(:new).with(subject, anything, anything)

          subject.neighbors(model)
        end

        it 'should set the mapper to the appropriate mapper of model' do
          model_class = double
          stub_const('Model', double)
          expect(Guacamole::AqlQuery).to receive(:new).with(anything,instance_of(Guacamole::EdgeCollection::AnnotatedEdgeMapper), anything)

          subject.neighbors(model)
        end

        it 'should have no :for_in part' do
          expect(Guacamole::AqlQuery).to receive(:new).with(anything, anything, hash_including(for_in: nil))

          subject.neighbors(model)
        end

        it 'should have no :return_as part' do
          expect(Guacamole::AqlQuery).to receive(:new).with(anything, anything, hash_including(return_as: nil))

          subject.neighbors(model)
        end

        it 'should have the query string set to NEIGHBORS_AQL_STRING' do
          expect(aql_query).to receive(:aql_fragment=).with(Guacamole::EdgeCollection::NEIGHBORS_AQL_STRING)

          subject.neighbors(model)
        end

        it 'should have the bind_parameters set to bind_parameters' do
          expect(aql_query).to receive(:bind_parameters=).with(bind_parameters)

          subject.neighbors(model)
        end
      end
    end
  end
end
