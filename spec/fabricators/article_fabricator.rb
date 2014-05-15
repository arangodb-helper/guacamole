# -*- encoding: utf-8 -*-

Fabricator(:article) do
  title 'And then there was silence'
  unique_attribute { sequence(:unique_attribute) { |i| "unique attribute #{i}"} }
end

Fabricator(:article_with_two_comments, from: Article) do
  title 'I have two comments'
  comments(count: 2) { |attrs, i| Fabricate.build(:comment, text: "I'm comment number #{i}") }
end
