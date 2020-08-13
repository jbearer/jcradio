require 'rspotify'

class Trigram < ActiveRecord::Base
  include Fuzzily::Model
end

class Song < ActiveRecord::Base

    include SongsHelper

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
        spotify_songs = RSpotify::Track.search(entry)

        songs = []

        spotify_songs.each do |ss|

            # first_letter
            songs.append(Song.new({
                                # TODO: gsub hacks are so '<%=song.artist%>'
                                # is parsed correctly in songs/index.html.erb
                'title'         => ss.name.gsub('\'', ''),
                'artist'        => ss.artists.first.name.gsub('\'', ''),  # Bear's Den hack
                'album'         => ss.album.name,
                'source'        => "Spotify",
                'source_id'     => ss.id,
                'duration'      => ss.duration_ms,
                'uri'           => ss.uri,
                'first_letter'  => SongsHelper.first_letter(ss.name),
                'next_letter'   => SongsHelper.calculate_next_letter(ss.name)
            }))
        end

        # TODO: "More results" button
        songs
    end

end
