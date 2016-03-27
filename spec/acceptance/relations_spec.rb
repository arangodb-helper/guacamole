# -*- encoding : utf-8 -*-
require 'guacamole'
require 'acceptance/spec_helper'

require 'fabricators/book'
require 'fabricators/author'

class Authorship
  include Guacamole::Edge

  from :authors
  to   :books
end

class BooksCollection
  include Guacamole::Collection

  map do
    attribute :author, via: Authorship, inverse: true
  end
end

class AuthorsCollection
  include Guacamole::Collection

  map do
    attribute :books, via: Authorship
  end
end

describe 'Graph based relations' do

  context 'having a start vertex and multiple target vertices' do
    context 'all are new' do
      let(:suzanne_collins) { Fabricate.build(:author, name: 'Suzanne Collins') }

      let(:the_hunger_games) { Fabricate.build(:book, title: 'The Hunger Games') }
      let(:catching_fire) { Fabricate.build(:book, title: 'Catching Fire') }
      let(:mockingjay) { Fabricate.build(:book, title: 'Mockingjay') }
      let(:panem_trilogy) { [the_hunger_games, catching_fire, mockingjay] }

      it 'should create the start, all targets and connect them' do
        suzanne_collins.books = panem_trilogy
        AuthorsCollection.save suzanne_collins

        author = AuthorsCollection.by_key(suzanne_collins.key)

        expect(author.books.map(&:title)).to match_array panem_trilogy.map(&:title)
      end

      it 'should populate the `key` and `rev` attribute of ALL vertices' do
        suzanne_collins.books = panem_trilogy
        AuthorsCollection.save suzanne_collins

        expect(suzanne_collins.key).not_to be_nil
        expect(suzanne_collins.rev).not_to be_nil

        panem_trilogy.each do |book|
          expect(book.key).not_to be_nil, "Book '#{book.title}' should have got a key"
          expect(book.rev).not_to be_nil, "Book '#{book.title}' should have got a rev"
        end
      end
    end

    context 'one target is new' do
      let(:suzanne_collins) { Fabricate.build(:author, name: 'Suzanne Collins') }

      let(:the_hunger_games) { Fabricate(:book, title: 'The Hunger Games') }
      let(:catching_fire) { Fabricate(:book, title: 'Catching Fire') }
      let(:mockingjay) { Fabricate.build(:book, title: 'Mockingjay') }
      let(:panem_trilogy) { [the_hunger_games, catching_fire, mockingjay] }

      it 'should create the start, the new target and connect both the new and existing ones' do
        suzanne_collins.books = panem_trilogy
        AuthorsCollection.save suzanne_collins

        author = AuthorsCollection.by_key(suzanne_collins.key)

        expect(author.books.map(&:title)).to match_array panem_trilogy.map(&:title)
      end
    end

    context 'existing start gets another target' do
      let(:suzanne_collins) { Fabricate(:author, name: 'Suzanne Collins') }

      let(:the_hunger_games) { Fabricate(:book, title: 'The Hunger Games') }
      let(:catching_fire) { Fabricate(:book, title: 'Catching Fire') }
      let(:mockingjay) { Fabricate.build(:book, title: 'Mockingjay') }
      let(:panem_trilogy) { [the_hunger_games, catching_fire, mockingjay] }

      before do
        suzanne_collins.books = [the_hunger_games, catching_fire]
        AuthorsCollection.save suzanne_collins
      end

      it 'should save the new target and connect it to the start' do
        suzanne_collins.books << mockingjay
        AuthorsCollection.save suzanne_collins

        author = AuthorsCollection.by_key(suzanne_collins.key)

        expect(author.books.map(&:title)).to match_array panem_trilogy.map(&:title)
      end
    end

    context 'new connection between existing start and existing target' do
      let(:suzanne_collins) { Fabricate(:author, name: 'Suzanne Collins') }

      let(:the_hunger_games) { Fabricate(:book, title: 'The Hunger Games') }
      let(:catching_fire) { Fabricate(:book, title: 'Catching Fire') }
      let(:mockingjay) { Fabricate(:book, title: 'Mockingjay') }
      let(:panem_trilogy) { [the_hunger_games, catching_fire, mockingjay] }

      before do
        suzanne_collins.books = [the_hunger_games, catching_fire]
        AuthorsCollection.save suzanne_collins
      end

      it 'should just add a connection between start and target' do
        suzanne_collins.books << mockingjay
        AuthorsCollection.save suzanne_collins

        author = AuthorsCollection.by_key(suzanne_collins.key)

        expect(author.books.map(&:title)).to match_array panem_trilogy.map(&:title)
      end
    end

    context 'remove an existing connection' do
      let(:suzanne_collins) { Fabricate(:author, name: 'Suzanne Collins') }

      let(:the_hunger_games) { Fabricate(:book, title: 'The Hunger Games') }
      let(:catching_fire) { Fabricate(:book, title: 'Catching Fire') }
      let(:mockingjay) { Fabricate(:book, title: 'Mockingjay') }
      let(:deathly_hallows) { Fabricate(:book, title: 'Deathly Hallows') }
      let(:panem_trilogy) { [the_hunger_games, catching_fire, mockingjay] }

      let(:authorships_count) { -> { AuthorshipsCollection.by_example(_from: suzanne_collins.arangodb_id).count } }

      before do
        suzanne_collins.books = [the_hunger_games, catching_fire, mockingjay, deathly_hallows]
        AuthorsCollection.save suzanne_collins
      end

      it 'should remove the edge' do
        suzanne_collins.books.pop

        expect { AuthorsCollection.save suzanne_collins }.to change(&authorships_count).by -1
      end

      it 'should not remove the target vertex' do
        suzanne_collins.books.pop

        AuthorsCollection.save suzanne_collins

        expect(BooksCollection.by_key(deathly_hallows.key)).not_to be_nil
      end

      context 'removing the target' do
        # This is just a sanity check at this point since it is handled by ArangoDB itself
        it 'should remove the edge too' do
          expect { BooksCollection.delete(deathly_hallows) }.to change(&authorships_count).by -1
        end
      end
    end

    context 'remove one target should remove the edge too' do
      let(:suzanne_collins) { Fabricate(:author, name: 'Suzanne Collins') }

      let(:the_hunger_games) { Fabricate(:book, title: 'The Hunger Games') }
      let(:catching_fire) { Fabricate(:book, title: 'Catching Fire') }
      let(:mockingjay) { Fabricate(:book, title: 'Mockingjay') }
      let(:deathly_hallows) { Fabricate(:book, title: 'Deathly Hallows') }
      let(:panem_trilogy) { [the_hunger_games, catching_fire, mockingjay] }

      let(:authorships_count) { -> { AuthorshipsCollection.by_example(_from: suzanne_collins.arangodb_id).count } }

      before do
        suzanne_collins.books = [the_hunger_games, catching_fire, mockingjay, deathly_hallows]
        AuthorsCollection.save suzanne_collins
      end
    end
  end

  context 'having the target vertex and one target' do
    context 'all are new' do
      let(:suzanne_collins) { Fabricate.build(:author, name: 'Suzanne Collins') }

      let(:the_hunger_games) { Fabricate.build(:book, title: 'The Hunger Games') }

      it 'should create the target, the start and connects them' do
        the_hunger_games.author = suzanne_collins
        BooksCollection.save the_hunger_games

        book = BooksCollection.by_key the_hunger_games.key

        expect(book.author.name).to eq suzanne_collins.name
      end
    end

    context 'the target is new' do
      let(:suzanne_collins) { Fabricate.build(:author, name: 'Suzanne Collins') }

      let(:the_hunger_games) { Fabricate(:book, title: 'The Hunger Games') }

      it 'should create the start and make the connection' do
        the_hunger_games.author = suzanne_collins
        BooksCollection.save the_hunger_games

        book = BooksCollection.by_key the_hunger_games.key

        expect(book.author.name).to eq suzanne_collins.name
      end
    end

    context 'existing target gets another start' do
      let(:jk_rowling) { Fabricate.build(:author, name: 'J.K. Rowling') }
      let(:suzanne_collins) { Fabricate.build(:author, name: 'Suzanne Collins') }

      let(:the_hunger_games) { Fabricate(:book, title: 'The Hunger Games') }

      before do
        the_hunger_games.author = jk_rowling
        BooksCollection.save the_hunger_games
      end

      it 'should create the new target and connect it with the start' do
        the_hunger_games.author = suzanne_collins
        BooksCollection.save the_hunger_games
        book = BooksCollection.by_key the_hunger_games.key
        expect(book.author.name).to eq suzanne_collins.name
      end
    end

    context 'new connection between existing start and existing target' do
      let(:suzanne_collins) { Fabricate(:author, name: 'Suzanne Collins') }

      let(:the_hunger_games) { Fabricate(:book, title: 'The Hunger Games') }

      it 'should just connect the target with the start' do
        the_hunger_games.author = suzanne_collins
        BooksCollection.save the_hunger_games

        book = BooksCollection.by_key the_hunger_games.key

        expect(book.author.name).to eq suzanne_collins.name
      end
    end
  end

  context 'update an existing member in a relationship' do
    let(:suzanne_collins) { Fabricate(:author, name: 'Suzanne Collin') }
    let(:the_hunger_games) { Fabricate(:book, title: 'The Hunger Game') }

    before do
      suzanne_collins.books << the_hunger_games
      AuthorsCollection.save suzanne_collins
      Guacamole::IdentityMap.reset
    end

    it 'should update an existing start document in a relations' do
      suzanne_collins.name = 'Suzanne Collins'
      AuthorsCollection.save suzanne_collins
      Guacamole::IdentityMap.reset

      reloaded_author = AuthorsCollection.by_key(suzanne_collins.key)

      expect(reloaded_author.name).to eq 'Suzanne Collins'
    end

    it 'should update an existing target document in a relation' do
      the_hunger_games.title = 'The Hunger Games'
      BooksCollection.save the_hunger_games
      Guacamole::IdentityMap.reset

      reloaded_book = BooksCollection.by_key(the_hunger_games.key)

      expect(reloaded_book.title).to eq 'The Hunger Games'
    end

    it 'should update both' do
      the_hunger_games.title = 'The Hunger Games'
      suzanne_collins.name = 'Suzanne Collins'
      AuthorsCollection.save suzanne_collins
      Guacamole::IdentityMap.reset

      reloaded_author = AuthorsCollection.by_key(suzanne_collins.key)
      reloaded_book = BooksCollection.by_key(the_hunger_games.key)

      expect(reloaded_author.name).to eq 'Suzanne Collins'
      expect(reloaded_book.title).to eq 'The Hunger Games'
    end

    it 'should update the rev` attribute of ALL affected models' do
      the_hunger_games_old_rev = the_hunger_games.rev
      suzanne_collins_old_rev  = suzanne_collins.rev

      the_hunger_games.title = 'The Hunger Games'
      suzanne_collins.name = 'Suzanne Collins'
      AuthorsCollection.save suzanne_collins

      expect(the_hunger_games.rev).not_to eq the_hunger_games_old_rev
      expect(suzanne_collins.rev).not_to eq suzanne_collins_old_rev
    end
  end
end
