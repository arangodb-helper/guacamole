[![RubyDoc](http://img.shields.io/badge/📄-RubyDoc-be1d77.svg)](http://rubydoc.info/gems/guacamole/frames)
[![Build Status](http://img.shields.io/travis/triAGENS/guacamole.svg)](https://travis-ci.org/triAGENS/guacamole)
[![Code Climate](http://img.shields.io/codeclimate/github/triAGENS/guacamole.svg)](https://codeclimate.com/github/triAGENS/guacamole)
[![Inline docs](http://inch-ci.org/github/triAGENS/guacamole.svg)](http://inch-ci.org/github/triAGENS/guacamole)
[![Gem Version](http://img.shields.io/gem/v/guacamole.svg)](https://rubygems.org/gems/guacamole)
[![Stories in Ready](http://badge.waffle.io/triAGENS/guacamole.png?label=ready&title=ready)](https://waffle.io/triAGENS/guacamole)

# Guacamole

Guacamole is an Object Document Mapper (ODM) for the multi-model NoSQL database [ArangoDB](https://www.arangodb.com/). Its main goal is to support easy integration into Ruby on Rails but will likely work in other Rack-based frameworks as well. There are a couple of design goals behind Guacamole which should drive all our development effort:

  * Easy integration on the View layer (i.e. form builders)
  * Reflect the nature of NoSQL in general and ArangoDB in particular
  * Focus on long-term maintainability of your application

While the first two points don't need any further explanation we want to lay out the motivation behind the last point: 'Ease of use' is very important to us, but we made some fundamental decisions which will cause a steeper learning curve than other libraries, notably ActiveRecord. If you have a traditional Rails background you will find some things quite different. We decided to go this direction, because we think it better suites the features of ArangoDB. Applying the semantics of a different environment may help with the first steps but will become problematic if you further advance in your understanding of the possibilities.

That said we still think we provide a sufficient API that is quite easy to get hold of. It is just a bit different from what you were doing with ActiveRecord.

For a high-level introduction you can also refer to [this presentation](https://speakerdeck.com/railsbros_dirk/how-to-make-guacamole).

## Getting started (with a fresh Rails application)

Since Guacamole is in an alpha state we suggest you to create a new Rails application to play around with it. We don't recommend adding it to a production application.

First of all create your shiny new application, without ActiveRecord of course:

```shell
rails new --skip-active-record $my_awesome_app
```

Add this line to your application's Gemfile:

```ruby
gem 'guacamole'
```

And then install the new dependencies:

```shell
bundle install
```

### Adding Guacamole to an existing Rails application

Maybe you're bold and want to add Guacamole to an existing Rails application. In this case some things are different, because you already have an ORM configured. Throughout the remaining README you will find examples of using generators and rake tasks to support you. All the generators must be invoked with the `--orm guacamole` flag. Without this you will generate both, ActiveRecord and Guacamole files:

```shell
bundle exec rails generate model pony name:string birthday:date color:string --orm guacamole
```

Guacamole will not overwrite existing rake tasks and thus you need to invoke them with under the guacamole namespace:

```shell
rake db:guacamole:create
rake db:guacamole:purge
rake db:guacamole:drop
```

Everything else should work as described in the README. If you encounter any errors while working with an existing Rails application, please let us know.

### Configuration

After you created the application and installed the dependencies the first thing you need is a configuration file. The database connection is pretty much configured as expected: With a YAML file. Luckily you don't have to create this file by yourself but you can use a generator to do it for you:

```shell
bundle exec rails generate guacamole:config
```

This will create a default configuration at `config/guacamole.yml`:

```yaml
development:
  protocol: 'http'
  host: 'localhost'
  port: 8529
  password: ''
  username: ''
  database: 'pony_blog_development'
```

**Note**: If you use something like [dotenv](https://github.com/bkeepers/dotenv) we will process the config file with ERB before loading the YAML. Another way to configure the database connection is to provide a connection URI like this: `http://user:pass@localhost:8529/_db/pony_ville_db`. If you don't use authentication, just skip the user/password part. The connection URI must be provided as the environment variable `DATABASE_URL` and has precedence over the config file.

After you created a configuration file you can create the database as in any other Rails project:

```shell
bundle exec rake db:create
```

If you're using Capistrano or something else make sure you change your deployment recipes accordingly to use the `guacamole.yml` and not the `database.yml`. Of course you would want to add [authentication](https://docs.arangodb.com/ConfigureArango/Authentication.html) for the production environment. Additionally you may want to consider putting ArangoDB behind a SSL-proxy or use the [built in SSL support](https://docs.arangodb.com/ConfigureArango/Arangod.html).

Now where everything is set up we can go ahead and create our application's logic. Before we give you some code to copy and paste we first give you a general usage and design overview.

## Usage

One of the key features of Guacamole is the implementation of the [Data Mapper Pattern](http://martinfowler.com/eaaCatalog/dataMapper.html). This brings a lot of good things along, like

  * improved testability
  * separation of concerns and
  * easier to support database features like embedded objects

The gist of the pattern is you have two classes where you would have one when you use ActiveRecord: A `Collection` and a `Model`. The `Collection` is responsible for getting data from and writing data to the database. The `Model` represents the domain logic (i.e. attributes) and has no idea what a database is. Due to this you could far easier test the domain logic without a database dependency. But you have always two (or more) classes around. The following will introduce you to both those classes.

### Models

Models are representations of your data. They are not aware of the database but work independently of it. Guacamole ships with a generator for models:

```shell
bundle exec rails generate model pony name:string birthday:date color:string
```

This will generate both a `Model` **and** a `Collection` (more on that later). If you don't want a `Collection` to be created just add the `--skip-collection` flag to the generator. The `Model` will be written to `app/models/pony.rb` and it will have the following content:

```ruby
class Pony
  include Guacamole::Model

  attribute :name, String
  attribute :birthday, Date
  attribute :color, String
end
```

Since the database doesn't know anything about a schema we must define the attributes in the model class itself. At the same time this has the advantage to open the model class and see what attributes it has. An attribute is defined with the `attribute` class method. We use [Virtus](https://github.com/solnic/virtus) for this purpose. Basically you give the attribute a name and a type. The type have to be the actual class and **not** a string representation of the class. You could even define collection classes:

```ruby
class Pony
  include Guacamole::Model

  attribute :type, Array[String]
end
```

For further reference what is possible please refer to the [Virtus documentation](http://rubydoc.info/gems/virtus/1.0.2/frames). One thing to note here: Whenever you assign a value to an attribute Virtus will perform a type coercion:

```ruby
pinkie_pie = Pony.new
pinkie_pie.color = :pink
# => "pink"
pinkie_pie.type  = "Earthpony"
# => ["Earthpony"]
```

#### Timestamps

We will automatically add both a `created_at` and an `updated_at` attribute to all your models. Both will hold a `DateTime` and will be populated on creating or updating the model in the database.

#### The ID of a model

In ArangoDB a document has three internal fields: `_id`, `_key` and `_rev`. For a detailed explanation how these three work together please refer to the [ArangoDB documentation](https://docs.arangodb.com/Documents/DocumentAddress.html). Within Guacamole we will always use the `_key` because it is enough the identify any document within a collection. Both the `_key` and `_rev` attribute are available through the `Guacamole::Model#key` and `Guacamole::Model#rev` attribute. You don't have to do anything for this, we will take care of this for you.

Additionally you will find an `id` method on you models. This is just an alias for `key`. This was added for `ActiveModel::Conversion` compliance. You **should always** use `key`.

#### Validations

When including `Guacamole::Model` you will not only get the functionality of Virtus but some ActiveModel love, too. Besides the [`ActiveModel::Naming`](http://api.rubyonrails.org/classes/ActiveModel/Naming.html) and [`ActiveModel::Conversion`](http://api.rubyonrails.org/classes/ActiveModel/Conversion.html) module you will get [Validations](http://api.rubyonrails.org/classes/ActiveModel/Validations.html) as well. Thus you could just write something like this:

```ruby
class Pony
  include Guacamole::Model

  attribute :name, String
  attribute :color, String

  validates :color, presence: true
end

transparent_pony = Pony.new
transparent_pony.valid?
# => false
transparent_pony.errors[:color]
# => ["can't be blank"]
```

As the model doesn't know anything about the database you cannot define database-dependent validations here (i.e.: uniqueness). This logic has to be handled in the `Collection`. That said, we have no strategy how to model this in the `Collection`. If you have any idea about this we would love to hear about it.

### Collections

Collections are your gateway to the database. They persist your models and offer querying for them. They will translate the raw data from the database to your domain models and vice versa. By convention they are the pluralized version of the model with the suffix `Collection`. So given the model from above, this could be the following collection:

```ruby
class PoniesCollection
  include Guacamole::Collection
end
```

As with the models we provide a generator to help you creating your collection classes. In most cases you won't need to invoke this generator due to the model generator already created a collection for you. But if for any reason you need another collection without a model you could do it like this:

```shell
bundle exec rails generate collection ponies
```

Currently your options what you can do with a collection are quite limited. We will eventually add more features, but for now you basically have this features:

  * CRUD operations for your models
  * Where the "Read"-part is limited to [Simple Queries](https://docs.arangodb.com/SimpleQueries/README.html). But more on this later.
  * Mapping embedded models
  * Realizing basic associations

For all the mapping related parts you don't have any configuration options yet, but have to stick with the conventions. Obviously this will change in the future but for now there are more important parts to work on. Before we dig deeper into the mapping of embedded or associated models let us look at the CRUD functionality.

#### Create models

To create a model just pass it to the `save` method of the `Collection` in charge:

```ruby
pinkie = Pony.new(name: "Pinkie Pie")
PoniesCollection.save pinkie
# => #<Pony:0x124 …>
```

The `save` method will trigger model validation before writing it to the database. If the model is not valid `false` will be returned. All validation errors can be retrieved from the model itself. They are stored in `errors` attribute which is provided by `ActiveModel::Validations`.

Every model has a `persisted?` method which will return `false` unless the model is saved to the database and thus has a `key` assigned.

#### Update models

Updating models is just the same as creating models in the first place:

```ruby
existing_pony.name = "Applejack"
PoniesCollection.save existing_pony
# => #<Pony:0x1451 …>
```

**Note**: As of today there is **no dirty tracking**. Models will always be updated in the database when you call `save` – no matter if they have changed or not.

#### Delete models

You can `delete` models from the database by either passing the model to be deleted or just its key. In both cases the key will be returned:

```ruby
PoniesCollection.delete existing_pony
# => `existing_pony.key`
```

#### Retrieve models

As mentioned before querying for models is quite limited as of now. We only support [Simple Queries](https://docs.arangodb.com/SimpleQueries/README.html) at this point. You can perform the following basic operations with them:

  * Getting a single model `by_key`
  * Getting `all` models from a collection.
  * Query models `by_example`. You can **only** perform equality checks with this.
  * You can `skip` and `limit` the results

You always need to start a query by either calling `all` or `by_example`. You could chain those with `skip` and `limit`. The query to the database will only be performed when you actually access the documents:

```ruby
some_ponies = PoniesCollection.by_example(color: 'green').limit(10)
# => #<Guacamole::Query:0x1212 …>
some_ponies.first
# The request to the database is made
# => #<Pony:0x90u81 …>
```

We're well aware this is not sufficient for building sophisticated applications. We're are working on something to make [AQL](https://docs.arangodb.com/Aql/README.html) usable from Guacamole.

### Mapping

As the name "Data Mapper" suggests there is some sort of mapping going on behind the scenes. The mapping relates to the process of _mapping_ documents from the database to the domain models.

The `Collection` class will lookup the appropriate `Model` class based on its own name (i.e.: the `PoniesCollection` will look for a `Pony` class). Currently there is no option to configure this so you're stuck with our conventions (for now):

  * Collections in ArangoDB are the plural form of the `Model` class name
  * The `Collection` class is the plural form of the `Model` class name with the suffix `Collection`

Without any configuration we will just map the attributes present in your domain model. If you retrieve a document from the database that contains other attributes then your domain model they will be silently discarded. To illustrate this imagine we have a document in the `ponies` collection which looks like this:

```json
{
  "_key": "303",
  "_rev": "1019391",
  "name": "Applejack",
  "color": "green",
  "occupation": "Farmer"
}
```

When we receive this document and map it against the `Pony` model there won't be a `occupation` attribute:

```ruby
class Pony
  include Guacamole::Model

  attribute :name, String
  attribute :color, String
end

pony = PoniesCollection.by_key "303"
pony.color
# => 'green'
pony.occupation
# => NoMethodError: undefined method `occupation' for #<Pony:0x00000105fc77f8>
```

Currently there is no option to change the mapping of attributes. If you want to map more or less attributes you should create another model for that purpose.

#### Associations

**TODO: This needs some work to include relations**
Besides simple attributes we want to handle associations between models. To add an association between your models you have two options: __embedded__ and __referenced__.

#### Embedded references

If you go with the `embeds` option the embedded model will be stored within the **same** document in the database. The comments of a blog post are a good example where this can be handy. While the database will have only one document the domain can still know about a `Comment` and a `Post`. In this case you would end up with two models and one collection:

```ruby
class Comment
  include Guacamole::Model

  attribute :text, String
end

class Post
  include Guacamole::Model

  attribute :title, String
  attribute :body,  String
  attribute :comments, Array[Comment]
end

class PostsCollection
  include Guacamole::Collection

  map do
    embeds :comments
  end
end
```

As you can see, from the model perspective there is nothing special about an embedded association. It is just another attribute on the `Post` class. How this is stored will be configured where it is handled: In the `PostsCollection`. Within the `map` block you put all the mapping related configuration. The `embeds` method will make sure that `Comment`s are correctly stored and received within the database. Be aware that embedded models will not have any `_key`, `_id` or `_rev` attribute. But they will have the time stamp attributes correctly populated. Within ArangoDB the resulting document will look like this:

```json
{
  "_id": "...",
  "_rev": "...",
  "_key": "...",
  "title": "The grand blog post",
  "body": "Lorem ipsum [...]",
  "create_at": "2014-05-03T16:55:43+02:00",
  "updated_at": "2014-05-03T16:55:43+02:00",
  "comments": [
    {
      "text": "This was really a grand blog post",
      "create_at": "2014-05-08T16:55:43+02:00",
      "updated_at": "2014-05-08T16:55:43+02:00"
    },
    {
      "text": "I don't think it was that great",
      "create_at": "2014-05-04T16:55:43+02:00",
      "updated_at": "2014-05-04T16:55:43+02:00"
    }
  ]
}
```

**Note**: Again this will only work if you stick with the convention. So far there is no support to configure this more fine grained.

### Relations

**>>>> Insert documentation for relations here!**

### Callbacks

Guacamole allows you to define callbacks for various actions performed on a model. Those callbacks need to be defined in a dedicate class per model. For example to hash the password of a user prior creating the document in the database you would write something like the following:

```ruby
class UserCallbacks
  include Guacamole::Callbacks

  before_create :encrypt_password

  def encrypt_password
    object.encrypted_password = BCrypt::Password.create(object.password)
  end
end
```

Whenever callbacks needs to be executed for a model we create an instance of the specified callback with that model. You have access to the model via the `object` method. To specify a callback for a model you must use the `callbacks` method in that model:

```ruby
class User
  include Guacamole::Model

  callbacks :user_callbacks
end
``` 

You can define callbacks for the following actions:

 * `before_validate`
 * `around_validate`
 * `after_validate`
 * `before_save`
 * `around_save`
 * `after_save`
 * `before_create`
 * `around_create`
 * `after_create`
 * `before_update`
 * `around_update`
 * `after_update`
 * `before_delete`
 * `around_delete`
 * `after_delete`

The order of the callback execution is as follows:

**Creating an object**

 * `before_validation`
 * `after_validation`
 * `before_save`
 * `around_save`
 * `before_create`
 * `around_create`
 * `after_create`
 * `after_save`

**Updating an object**

 * `before_validation`
 * `after_validation`
 * `before_save`
 * `around_save`
 * `before_update`
 * `around_update`
 * `after_update`
 * `after_save`

**Destroying an object**

 * `before_delete`
 * `around_delete`
 * `after_delete`

The order of the callback execution is as follows:

**Creating an object**

 1. `before_validation`
 2. `after_validation`
 3. `before_save`
 4. `around_save`
 5. `before_create`
 6. `around_create`
 7. `after_create`
 8. `after_save`

**Updating an object**

 1. `before_validation`
 2. `after_validation`
 3. `before_save`
 4. `around_save`
 5. `before_update`
 6. `around_update`
 7. `after_update`
 8. `after_save`

**Destroying an object**

 1. `before_delete`
 2. `around_delete`
 3. `after_delete`

#### Generator Support

Of course we provide a generator to help you setting the required files up:

```shell
rails generate guacamole:callbacks pony
```

This will create the callback file, a test template and adds the appropriate register call to the model file.

## Integration into the Rails Ecosystem™

Guacamole is a very young project. A lot of stuff is missing but still, if you want to get started with ArangoDB and are using Ruby/Rails it will give you a nice head start. Besides a long TODO list we want to hint to some points to help you integrate Guacamole with the rest of the Rails ecosystem:

### Testing

Currently we're not providing any testing helper, thus you need to make sure to cleanup the database yourself before each run. You can look at the [`spec/acceptance/spec_helper.rb`](https://github.com/triAGENS/guacamole/blob/master/spec/acceptance/spec_helper.rb) of Guacamole for inspiration of how to do that.

For test data generation we're using the awesome [Fabrication gem](http://www.fabricationgem.org/). Again you find some usage examples in Guacamole's own acceptance tests. We haven't tested Factory Girl yet but it eventually will work too.

### Authentication

Any integration into an authentication framework needs to be done by you. At this time we have nothing to share with you about this topic.

### Forms

While we haven't tested them, they should probably work due to the ActiveModel compliance. But again, this is not confirmed and you need to try it out yourself.

If you give Guacamole a try, please feel free to ask us any question or give us feedback about anything on your mind. This is really crucial for us and we would be more than happy to hear back from you.

## Todos

While there are a lot of open issues we would like to present you a high level overview of upcoming features:

  * Basic AQL support for more useful queries
  * Configuration of mapping
  * Callbacks and dirty tracking for models
  * An example Rails application to be used as both an acceptance test suite and a head start for Guacamole and ArangoDB
  * An AQL query builder

### AQL Support

As mentioned before we're working on [something more sophisticated to support AQL](https://github.com/moonglum/brazil/issues/8). But this will not be finished any time soon. That said, there is still a way to to perform AQL queries against ArangoDB. For simple queries you can do something like this:

```ruby
PoniesCollection.by_aql('FILTER pony.name == @name', name: 'Rainbow Dash')
```

The result of this will a correctly mapped Array of `Pony` models. If this is not enough thou, don't worry, you can get really fancy with this. Due to this you can deactivate the automatic mapping of the response. In that case you will receive just a raw document you can work with. **Note**: Please use only this form to pass parameters into a query. Using string interpolation will leave you vulnerable to AQL-injections.

For more information about usage please refer to the RDoc and the code.

## Issues or Questions

If you find a bug in this gem, please report it on [our tracker](https://github.com/triAGENS/guacamole/issues). We use [Waffle.io](https://waffle.io/triagens/guacamole) to manage the tickets – go there to see the current status of the ticket. If you have a question, just contact us via the [mailing list](https://groups.google.com/forum/?fromgroups#!forum/ashikawa) – we are happy to help you :smile:

## Contributing

If you want to contribute to the project, see [CONTRIBUTING.md](CONTRIBUTING.md) for details. It contains information on our process and how to set up everything. The following people have contributed to this project:

* Lucas Dohmen ([@moonglum](https://github.com/moonglum)): Developer
* Dirk Breuer ([@railsbros-dirk](https://github.com/railsbros-dirk)): Developer

## Inspiration

The work on Guacamole is heavily inspired by the remarkable work of the [ROM](http://rom-rb.org) team and especially by [Piotr Solnica](http://solnic.eu).
