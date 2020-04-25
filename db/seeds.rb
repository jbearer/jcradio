# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

def spotify_song(song)
    Song.create({source: "Spotify", source_id: "bogus"}.merge(song))
end

def spotify_station(station, songs)
    station = Station.create name: station
    songs.each_with_index do |song, i|
        user = User.create username: "User#{i}"
        SongsStations.create station: station, song: spotify_song(song), position: i, selector: user
    end
    station
end

if Rails.env.development?
    station = spotify_station "Jingle Churro", [
        {title: "Interlude", artist: "Alt-J", album: "An Awesome Wave", duration: 11},
        {title: "Down Down the Deep River", artist: "Okkervil River", album: "The Silver Gymnasium", duration: 12}
    ]

    now_playing = spotify_song title: "One Sweet World", artist: "Dave Matthews Band", album: "Under the Table and Dreaming"
    queue_entry = SongsStations.create station: station, song: now_playing, position: 0, selector: User.find(1)
    station.update now_playing: queue_entry
end
