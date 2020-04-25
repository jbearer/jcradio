require 'rspotify'

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

    def self.spotify_search(entry)
        # Currently only searches for the song.
        # TODO: Incorporate artist and album
        spotify_songs = RSpotify::Track.search(entry)

        songs = []

        spotify_songs.each do |ss|
            songs.append(Song.new({
                'title'     => ss.name,
                'artist'    => ss.artists.first.name,  # TODO: List multiple artists
                'album'     => ss.album.name,
                'source'    => "Spotify",
                'source_id' => ss.id,
                'duration'  => ss.duration_ms
            }))
        end

        # TODO: "More results" button
        songs
    end

end
