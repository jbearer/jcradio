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
            # Known songs skip Spotify entirely so a rate-limited app token can't block them.
            Song.find_by(source: "Spotify", source_id: source_id) ||
                SongsHelper.get_or_create_from_spotify_record([find_spotify_track(source_id)], true).first
        else
            nil
        end
    end

    # RSpotify::Track.find uses the client-credentials app token, which stays 429 for many minutes
    # after a library-browse burst while the linked user's OAuth token keeps working.
    def self.find_spotify_track(source_id)
        spotify_user = $spotify_user
        return RSpotify::Track.find(source_id) if spotify_user.nil?

        begin
            response = RSpotify::User.oauth_get(spotify_user.id, "tracks/#{source_id}")
            RSpotify::Track.new response
        rescue RestClient::TooManyRequests
            RSpotify::Track.find(source_id)
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
        # Spotify capped search limit at 10 in Feb 2026; RSpotify 2.9.2 defaults to 20.
        spotify_songs = RSpotify::Track.search(entry, limit: 10)

        songs = SongsHelper.get_or_create_from_spotify_record(spotify_songs)

        # TODO: "More results" button
        songs
    end

end
