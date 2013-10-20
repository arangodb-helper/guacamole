# -*- encoding : utf-8 -*-

require 'spec_helper'
require 'guacamole/query'

describe Guacamole::Query do
  let(:connection) { double('Connection') }
  let(:mapper) { double('Mapper') }

  subject { Guacamole::Query.new(connection, mapper) }

  its(:connection) { should be connection }
  its(:mapper) { should be mapper }

  it 'should be enumerable' do
    expect(Guacamole::Query.ancestors).to include Enumerable
  end

  describe 'each' do
    let(:result) { double }
    let(:document) { double }
    let(:model) { double }
    let(:limit) { double }
    let(:skip) { double }

    before do
      allow(result).to receive(:each)
        .and_yield(document)

      allow(mapper).to receive(:document_to_model)
        .and_return(model)
    end

    context 'no example was provided' do
      before do
        allow(connection).to receive(:all)
          .and_return(result)
      end

      it 'should get all documents' do
        expect(connection).to receive(:all)
          .with({})

        subject.each { }
      end

      it 'should iterate over the resulting documents' do
        expect(result).to receive(:each)

        subject.each { }
      end

      it 'should yield the models to the caller' do
        expect { |b| subject.each(&b) }.to yield_with_args(model)
      end

      it 'should return an enumerator when called without a block' do
        expect(subject.each).to be_an Enumerator
      end

      it 'should accept a limit' do
        expect(connection).to receive(:all)
          .with(hash_including limit: limit)

        subject.limit(limit).each { }
      end

       it 'should accept a skip' do
         expect(connection).to receive(:all)
           .with(hash_including skip: skip)

         subject.skip(skip).each { }
       end
    end

    context 'an example was provided' do
      let(:example) { double }
      before do
        subject.example = example

        allow(connection).to receive(:by_example)
          .and_return(result)
      end

      it 'should query by the given example' do
        expect(connection).to receive(:by_example)
          .with(example, {})

        subject.each { }
      end

      it 'should iterate over the resulting documents' do
        expect(result).to receive(:each)

        subject.each { }
      end

      it 'should yield the models to the caller' do
        expect { |b| subject.each(&b) }.to yield_with_args(model)
      end

      it 'should return an enumerator when called without a block' do
        expect(subject.each).to be_an Enumerator
      end

      it 'should accept a limit' do
        expect(connection).to receive(:by_example)
          .with(example, hash_including(limit: limit))

        subject.limit(limit).each { }
      end

       it 'should accept a skip' do
         expect(connection).to receive(:by_example)
           .with(example, hash_including(skip: skip))

         subject.skip(skip).each { }
       end
    end
  end

  describe 'first' do
    context 'no example was provided' do
      it 'should return the first result of the all query' do
        first_result = double
        first_result_as_model = double
        results = [first_result]

        allow(mapper).to receive(:document_to_model)
          .with(first_result)
          .and_return(first_result_as_model)

        allow(connection).to receive(:all)
          .and_return(results)

        expect(subject.first).to be first_result_as_model
      end
    end
  end
end
