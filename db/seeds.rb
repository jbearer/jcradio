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

def spotify_station(station, songs=[])

    station = Station.create name: station, queue_pos: 0, now_playing: QueueEntry.create({song: spotify_song({title: "test_song"})})
    songs.each_with_index do |song, i|
        user = User.create username: "User#{i}"
        QueueEntry.create station: station, song: spotify_song(song), position: i, selector: user
    end
    station
end

if Rails.env.development?

    User.create username: "Austin"
    User.create username: "Aurora"
    User.create username: "Jeb"
    User.create username: "Daniel"

    spotify_station "Jingle Churro"
end

vapid_key = Webpush.generate_key
Vapid.create public_key: vapid_key.public_key, private_key: vapid_key.private_key
