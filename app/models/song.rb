require 'rspotify'

class Trigram < ActiveRecord::Base
  include Fuzzily::Model
end

class Song < ActiveRecord::Base

    include SongsHelper

    has_and_belongs_to_many :stations
    has_many :queue_entries
    has_many :upvotes, through: :queue_entries

    fuzzily_searchable :title, :artist, :album

    def as_json(options=nil)
        super only: [:id, :title, :album, :artist, :first_letter, :next_letter, :uri, :last_played]
    end

    def self.get(source, source_id)
        if source == "Spotify"
            SongsHelper.get_or_create_from_spotify_record([RSpotify::Track.find(source_id)], true).first
        else
            nil
        end
    end

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

    def self.spotify_search(entry)
        spotify_songs = RSpotify::Track.search(entry)

        songs = SongsHelper.get_or_create_from_spotify_record(spotify_songs)

        # TODO: "More results" button
        songs
    end

end
