class Trigram < ActiveRecord::Base
  include Fuzzily::Model
end

class Song < ActiveRecord::Base
    has_and_belongs_to_many :stations

    fuzzily_searchable :title, :artist, :album

    def self.fuzzy_search(keywords)
        counts = {}
        keywords.each do |kw|
            [:title, :artist, :album].each do |prop|
                send('find_by_fuzzy_' + prop.to_s, kw).each do |song|
                    if counts.key? song
                        counts[song] += 1
                    else
                        counts[song] = 1
                    end
                end
            end
        end

        counts.sort_by { |song, count| -count }.map { |song, count| song }
    end
end
