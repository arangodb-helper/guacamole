# -*- encoding: utf-8 -*-

srand(26071992) # Seed the pseudo random generator for predictable output during testing

Fabricator(:article) do
  title 'And then there was silence'
  unique_attribute { sequence(:unique_attribute) { |i| "unique attribute #{i}" } }
  location { [rand(181)-90, rand(361)-180] }
end

Fabricator(:article_with_two_comments, from: Article) do
  title 'I have two comments'
  comments(count: 2) { |attrs, i| Fabricate.build(:comment, text: "I'm comment number #{i}") }
end
