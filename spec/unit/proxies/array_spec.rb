# -*- encoding : utf-8 -*-

require 'spec_helper'
require 'guacamole/proxies/array'

describe Guacamole::Proxies::Array do
  let(:model) { double('Model') }
  let(:edge_class) { double('EdgeClass') }
  let(:responsible_edge_collection) { double('EdgeCollection') }
  let(:edge_collection_name)        { 'name_of_the_edge_collection' }

  before do
    allow(Guacamole::EdgeCollection).to receive(:for).with(edge_class).and_return(responsible_edge_collection)
    allow(responsible_edge_collection).to receive(:collection_name).and_return(edge_collection_name)
  end

  context 'initialization' do
    subject { Guacamole::Proxies::Array }

    it 'should take a model and edge class as params' do
      expect { subject.new(model, edge_class) }.not_to raise_error
    end
  end

  context 'initialized proxy' do
    let(:proxy_options) { {} }
    let(:neighbors) { double('Neighbors', options:{}) }
    let(:related_model) { double('RelatedModel', name: 'The Model') }
    let(:query_result) { double('EdgeDocument', edge_attributes: {}, model: related_model) }

    before do
      allow(responsible_edge_collection).to receive(:neighbors).with(model, :outbound). and_return(neighbors)
      allow(neighbors).to receive(:call).and_return(neighbors)
    end

    subject { Guacamole::Proxies::Array.new(model, edge_class, proxy_options) }

    # The following is not possible with `its` because `send` is not available
    it 'should have an edge_collection' do
      expect(subject.edge_collection).to eq responsible_edge_collection
    end

    it 'should have a direction' do
      expect(subject.direction).to eq :outbound
    end

    it 'should know it the proxy relates to a collection' do
      expect(subject.relates_to_collection?).to eq true
    end

    context 'with relation to collection' do
      let(:proxy_options) { { just_one: false } }
      let(:related_models) { double('RelatedModels', count: 1) }

      before do
        allow(neighbors).to receive(:to_a).and_return(neighbors)
        allow(responsible_edge_collection).to receive(:neighbors).
          with(model, subject.direction).
          and_return(neighbors)
        allow(neighbors).to receive(:map).and_return([related_model])
      end

      it 'should call the #neighbors method on the appropriate edge collection' do
        expect(subject.count).to eq related_models.count
      end
    end

    context 'with relation to single model' do
      let(:proxy_options) { { just_one: true } }

      before do
        allow(neighbors).to receive(:first).and_return(query_result)
        allow(neighbors).to receive(:to_a).and_return(neighbors)
        allow(responsible_edge_collection).to receive(:neighbors).
          with(model, subject.direction).
          and_return(neighbors)
        allow(neighbors).to receive(:map).and_yield(related_model)
      end

      it 'should call the #neighbors method on the appropriate edge collection' do
        expect(subject.name).to eq related_model.name
      end
    end
  end
end

