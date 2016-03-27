# -*- encoding : utf-8 -*-

require 'spec_helper'
require 'guacamole/proxies/relation'

describe Guacamole::Proxies::Relation do
  let(:model) { double('Model') }
  let(:edge_class) { double('EdgeClass') }
  let(:responsible_edge_collection) { double('EdgeCollection') }
  let(:edge_collection_name)        { 'name_of_the_edge_collection' }
  let(:query) { double(Guacamole::Query) }
  let(:target) { double('Target') }

  before do
    allow(Guacamole::EdgeCollection).to receive(:for).with(edge_class).and_return(responsible_edge_collection)
    allow(responsible_edge_collection).to receive(:collection_name).and_return(edge_collection_name)
  end

  context 'initialization' do
    subject { Guacamole::Proxies::Relation }

    it 'should take a model and edge class as params' do
      expect { subject.new(model, edge_class) }.not_to raise_error
    end
  end

  context 'initialized proxy' do
    let(:proxy_options) { {} }
    let(:query_options) {double('QueryOptions') }
    let(:neighbors) { double('Neighbors', options:query_options ) }

    subject { Guacamole::Proxies::Relation.new(model, edge_class, proxy_options) }

    before do
      subject.query = query

      allow(responsible_edge_collection).to receive(:neighbors).with(model, :outbound).and_return neighbors
      allow(neighbors).to receive(:to_a).and_return([])
    end

    # The following is not possible with `its` because `send` is not available
    it 'should have an edge_collection' do
      expect(subject.edge_collection).to eq responsible_edge_collection
    end

    it 'should have a direction' do
      expect(subject.direction).to eq :outbound
    end

    it 'should know if the proxy relates to a collection' do
      expect(subject.relates_to_collection?).to eq true
    end

    it 'should delegate query methods to the query' do
      allow(query).to receive(:methods).and_return [:limit, :send]
      allow(query).to receive(:method).with(:limit).and_return(query)
      allow(query).to receive(:owner).and_return 'Guacamole::Query'
      expect(query).to receive(:send).with(:limit, 10)

      subject.limit(10)
    end

    it 'should delegate methods to the target' do
      allow(query).to receive(:methods).and_return [:limit, :send ]
      allow(target).to receive(:methods).and_return [ :to_a, :send ]

      allow(query).to receive(:call).and_return(query)
      allow(query).to receive(:to_a).and_return(target)

      expect(target).to receive(:send).with(:to_a)

      subject.to_a
    end

    it 'should delegate methods to the query if both query and target define it' do
      allow(query).to receive(:methods).and_return [:limit, :send ]
      allow(target).to receive(:methods).and_return [ :to_a, :send ]

      allow(query).to receive(:call).and_return(query)
      allow(query).to receive(:to_a).and_return(target)
    end
  end
end
