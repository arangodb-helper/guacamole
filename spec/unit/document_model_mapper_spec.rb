# -*- encoding : utf-8 -*-

require 'spec_helper'
require 'guacamole/document_model_mapper'

class FancyModel
end

class FakeIdentityMap
  class << self
    def retrieve_or_store(*args, &block)
      block.call
    end
  end
end

describe Guacamole::DocumentModelMapper do
  subject { Guacamole::DocumentModelMapper }

  it 'should be initialized with a model class' do
    mapper = subject.new FancyModel, FakeIdentityMap
    expect(mapper.model_class).to eq FancyModel
  end

  context 'document mapper instance' do
    subject { Guacamole::DocumentModelMapper.new FancyModel, FakeIdentityMap }

    let(:model) { double('Model') }
    let(:model_class) { double('ModelClass') }

    before do
      allow(subject).to receive(:model_class).and_return(model_class)
      allow(model).to receive(:instance_of?).with(model_class).and_return(true)
    end

    it 'should know if it responsible for a certain model' do
      expect(subject.responsible_for?(model)).to be_truthy
    end
  end

  describe 'document_to_model' do
    subject { Guacamole::DocumentModelMapper.new FancyModel, FakeIdentityMap }

    let(:document)            { double('Ashikawa::Core::Document') }
    let(:document_attributes) { double('Hash') }
    let(:model_instance)      { double('ModelInstance').as_null_object }
    let(:some_key)            { double('Key') }
    let(:some_rev)            { double('Rev') }

    before do
      allow(subject.model_class).to receive(:new).and_return(model_instance)
      allow(document).to receive(:to_h).and_return(document_attributes)
      allow(document).to receive(:key).and_return(some_key)
      allow(document).to receive(:revision).and_return(some_rev)
    end

    it 'should create a new model instance from an Ashikawa::Core::Document' do
      expect(subject.model_class).to receive(:new).with(document_attributes)

      model = subject.document_to_model document
      expect(model).to eq model_instance
    end

    it 'should create a new model instance from an Ashikawa::Core::Document presented as Hash' do
      allow(document_attributes).to receive(:[]).with('_key').and_return(some_key)
      allow(document_attributes).to receive(:[]).with('_revision').and_return(some_rev)

      expect(subject.model_class).to receive(:new).with(document_attributes)

      model = subject.hash_to_model document.to_h
      expect(model).to eq model_instance
    end

    it 'should set the rev and key on a new model instance' do
      expect(model_instance).to receive(:key=).with(some_key)
      expect(model_instance).to receive(:rev=).with(some_rev)

      subject.document_to_model document
    end

    context 'with attributes as edge relations' do
      let(:attribute_with_edge_relation) do
        instance_double('Guacamole::DocumentModelMapper::Attribute', name: 'my_relation')
      end
      let(:relation_proxy) { double('Proxy') }
      let(:setter_for_relation) { double('SetterForRelation') }
      let(:virtus_collection_type) { double('VirtusCollection') }
      let(:virtus_hash_type) { double('VirtusHash') }

      before do
        allow(attribute_with_edge_relation).to receive(:setter).and_return(setter_for_relation)
        allow(subject).to receive(:edge_attributes).and_return([attribute_with_edge_relation])
        allow(subject).to receive(:build_proxy).
                           with(model_instance, attribute_with_edge_relation).
                           and_return(relation_proxy)
        stub_const('Virtus::Attribute::Collection::Type', virtus_collection_type)
        stub_const('Virtus::Attribute::Hash::Type', virtus_hash_type)
        allow(attribute_with_edge_relation).to receive(:type).with(model_instance).and_return(virtus_collection_type)
      end

      it 'should set first the key and rev and after that the proxy' do
        expect(model_instance).to receive(:key=).ordered
        expect(model_instance).to receive(:rev=).ordered
        expect(subject).to receive(:handle_related_documents).ordered

        subject.document_to_model document
      end

      it 'should set a proxy for each edge_attribute' do
        expect(model_instance).to receive(:send).with(setter_for_relation, relation_proxy)

        subject.document_to_model document
      end

      context 'setting the proxy' do
        let(:related_edge_class) { instance_double('Guacamole::Edge') }
        let(:relation_proxy_class) { Guacamole::Proxies::Relation }
        let(:relation_proxy) { instance_double('Guacamole::Proxies::Relation') }

        before do
          allow(attribute_with_edge_relation).to receive(:edge_class).and_return(related_edge_class)
          allow(attribute_with_edge_relation).to receive(:inverse?).and_return(false)
          allow(relation_proxy_class).to receive(:new).and_return(relation_proxy)
          allow(subject).to receive(:build_proxy).and_call_original
          allow(subject).to receive(:edge_attribute_a_collection?).and_return(false)
        end

        it 'should build the proxy with the model, the attribute class and options' do
          expect(relation_proxy_class).to receive(:new).
                                           with(model_instance, related_edge_class, hash_including(just_one: true, inverse: false)).
                                           and_return(relation_proxy)

          expect(subject.build_proxy(model_instance, attribute_with_edge_relation)).to eq relation_proxy
        end

        it 'should set the option :inverse based on the edge_attribute' do
          expect(subject).to receive(:edge_attribute_a_collection?).with(model_instance, attribute_with_edge_relation)

          subject.build_proxy(model_instance, attribute_with_edge_relation)
        end

        it 'should set the option :just_one based on the edge_attribute type' do
          inverse_value = double('InverseValue')
          allow(attribute_with_edge_relation).to receive(:inverse?).and_return(inverse_value)
          expect(relation_proxy_class).to receive(:new).
                                           with(anything, anything, hash_including(inverse: inverse_value))

          subject.build_proxy(model_instance, attribute_with_edge_relation)
        end

        it 'should check the edge_attribute type for a Virtus collection type' do
          model_class, attribute_set, attribute_type = [double] * 3

          allow(subject).to receive(:edge_attribute_a_collection?).and_call_original

          allow(model_instance).to receive(:class).and_return(model_class)
          allow(model_class).to receive(:attribute_set).and_return(attribute_set)
          allow(attribute_set).to receive(:[]).with(attribute_with_edge_relation.name).and_return(attribute_type)
          allow(attribute_type).to receive(:type).and_return(attribute_type)
          expect(attribute_type).to receive(:is_a?).with(virtus_collection_type).and_return(false)
          expect(attribute_type).to receive(:is_a?).with(virtus_hash_type).and_return(false)

          subject.edge_attribute_a_collection?(model_instance, attribute_with_edge_relation)
        end
      end
    end

    context 'with embedded ponies' do
      # This is handled by Virtus, we just need to provide a hash
      # and the coercing will be taken care of by Virtus
    end
  end

  describe 'model_to_document' do
    subject { Guacamole::DocumentModelMapper.new FancyModel, FakeIdentityMap }

    let(:model)            { double('Model') }
    let(:model_attributes) { double('Hash').as_null_object }

    before do
      allow(model).to receive(:attributes).and_return(model_attributes)
      allow(model_attributes).to receive(:dup).and_return(model_attributes)
    end

    it 'should transform a model into a simple hash' do
      expect(subject.model_to_document(model)).to eq model_attributes
    end

    it 'should return a copy of the model attributes hash' do
      expect(model_attributes).to receive(:dup).and_return(model_attributes)

      subject.model_to_document(model)
    end

    it 'should remove the key and rev attributes from the document' do
      expect(model_attributes).to receive(:except).with(:key, :rev)

      subject.model_to_document(model)
    end

    context 'with embedded ponies' do
      let(:somepony) { double('Pony') }
      let(:pony_array) { [somepony] }
      let(:ponylicious_attributes) { double('Hash').as_null_object }

      before do
        subject.embeds :ponies

        allow(model).to receive(:ponies)
          .and_return pony_array

        allow(somepony).to receive(:attributes)
          .and_return ponylicious_attributes
      end

      it 'should convert all embedded ponies to pony hashes' do
        expect(somepony).to receive(:attributes)
          .and_return ponylicious_attributes

        subject.model_to_document(model)
      end

      it 'should exclude key and rev on embedded ponies' do
        expect(ponylicious_attributes).to receive(:except)
          .with(:key, :rev)

        subject.model_to_document(model)
      end
    end

    context 'with attributes as edge relations' do
      let(:attribute_with_edge_relation) do
        instance_double('Guacamole::DocumentModelMapper::Attribute', name: 'my_relation')
      end

      before do
        allow(subject).to receive(:edge_attributes).and_return([attribute_with_edge_relation])
      end

      it 'should remove the attributes from the document' do
        expect(model_attributes).to receive(:delete).with('my_relation')

        subject.model_to_document(model)
      end
    end
  end

  describe 'embed' do
    subject { Guacamole::DocumentModelMapper.new FancyModel, FakeIdentityMap }

    it 'should remember which models to embed' do
      subject.embeds :ponies

      expect(subject.models_to_embed).to include :ponies
    end
  end

  describe 'attribute' do
    describe Guacamole::DocumentModelMapper::Attribute do
      subject { Guacamole::DocumentModelMapper::Attribute.new(:attribute_name) }

      its(:name) { should eq :attribute_name }
      its(:options) { should eq({}) }
      its(:getter) { should eq :attribute_name }
      its(:setter) { should eq 'attribute_name=' }

      context 'attributes for relations' do
        let(:edge_class) { double('SomeEdgeClass') }

        before do
          subject.options[:via] = edge_class
        end

        it 'should know if the attribute must be mapped via an edge' do
          expect(subject.map_via_edge?).to be_truthy
        end

        it 'should hold a reference to the edge class' do
          expect(subject.edge_class).to eq edge_class
        end
      end
    end

    subject { Guacamole::DocumentModelMapper.new FancyModel, FakeIdentityMap }

    it 'should add an attribute to be handled differently during the mapping' do
      subject.attribute :special_one

      expect(subject.attributes).to include Guacamole::DocumentModelMapper::Attribute.new(:special_one)
    end

    it 'should hold a list of all attributes to be considered during the mapping' do
      subject.attribute :some_attribute
      subject.attribute :another_attribute

      expect(subject.attributes.count).to eq 2
    end

    it 'should hold a list of all attributes to be mapped via Edges' do
      subject.attribute :normal_attribute
      subject.attribute :related_model, via: double('EdgeClass')

      expect(subject.edge_attributes).to include(an_object_having_attributes(name: :related_model))
    end
  end
end
