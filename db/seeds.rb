# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

def spotify_station(station, songs)
    station = Station.create name: station
    songs.each_with_index do |song, i|
        song = Song.create({source: "Spotify", source_id: "bogus"}.merge(song))
        SongsStations.create station: station, song: song, position: i
    end
end

if Rails.env.development?
    spotify_station "Jingle Churro", [
        {title: "Interlude", artist: "Alt-J", album: "An Awesome Wave"},
        {title: "Down Down the Deep River", artist: "Okkervil River", album: "The Silver Gymnasium"}
    ]
end
