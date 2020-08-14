require 'rspotify'

class Trigram < ActiveRecord::Base
  include Fuzzily::Model
end

class Song < ActiveRecord::Base

    include SongsHelper

    has_and_belongs_to_many :stations

    fuzzily_searchable :title, :artist, :album

    def self.get(source, source_id)
        if source == "Spotify"
            get_or_create_from_spotify_record(RSpotify::Track.find(source_id), true)
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

        songs = []

        spotify_songs.each do |ss|
            songs.append(get_or_create_from_spotify_record ss)
        end

        # TODO: "More results" button
        songs
    end

    def self.get_or_create_from_spotify_record(song, persist=false)
        result = Song.where(source: "Spotify", source_id: song.id).first
        if result
            return result
        end

        data = {
            title: song.name.gsub("'", ""),
            artist: song.artists.first.name.gsub("'", ""),
            album: song.album.name,
            source: "Spotify",
            source_id: song.id,
            uri: song.uri,
            duration: song.duration_ms,
            first_letter: SongsHelper.first_letter(song.name),
            next_letter: SongsHelper.calculate_next_letter(song.name)
        }

        if persist then
            Song.create data
        else
            Song.new data
        end
    end

end
