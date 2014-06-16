# -*- encoding : utf-8 -*-

require 'guacamole'
require 'acceptance/spec_helper'

# TODO: Figure out what is going on here
class Pony; end
require 'fabricators/pony'

class PoniesCollection
  include Guacamole::Collection
end

class Pony
  include Guacamole::Model

  attribute :name, String
  attribute :color, String
  attribute :type, Array[String]
end

describe 'BasicAQLSupport' do
  subject { PoniesCollection }

  let(:pegasus_pony) { Fabricate(:pony, type: ['Pegasus']) }
  let(:earth_pony) { Fabricate(:pony, type: ['Earthpony'], name: 'Candy Mane') }
  let(:unicorn_pegasus_pony) { Fabricate(:pony, type: ['Pegasus', 'Unicorn']) }

  context 'with experimental AQL support enabled' do
    before do
      Guacamole.configuration.experimental_features = [:aql_support]

      # TODO: This breaks the test
      [pegasus_pony, earth_pony, unicorn_pegasus_pony]
    end

    it 'should retrieve models by simple AQL queries' do
      pony_by_name = PoniesCollection.by_aql('FILTER pony.name == @name', name: 'Candy Mane').first
      expect(pony_by_name).to eq earth_pony
    end

    it 'should retrieve models by more complex AQL queries' do
      ponies_by_type = PoniesCollection.by_aql('FILTER POSITION(pony.type, @pony_type, false) == true',
                                               pony_type: 'Pegasus')
      expect(ponies_by_type).to include unicorn_pegasus_pony
      expect(ponies_by_type).to include pegasus_pony
    end

    it 'should allow a custom RETURN statement' do
      custom_color = 'fancy white pink with sparkles'
      pony_by_name = PoniesCollection.by_aql('FILTER pony.name == @name',
                                             { name: 'Candy Mane' },
                                             return_as: %Q{RETURN MERGE(pony, {"color": "#{custom_color}"})}).first
      expect(pony_by_name.color).to eq custom_color
    end

    it 'should allow to disable the mapping' do
      pony_hash = PoniesCollection.by_aql('FILTER pony.name == @name',
                                          { name: 'Candy Mane' },
                                          mapping: false ).first
      expect(pony_hash).to be_an(Ashikawa::Core::Document)
    end
  end

  context 'without experimental AQL support enabled' do
    before do
      Guacamole.configuration.experimental_features = []
    end

    it 'should raise an error accessing the AQL feature' do
      expect { PoniesCollection.by_aql("random AQL fragment") }.to raise_error(Guacamole::AQLNotSupportedError)
    end
  end

end
