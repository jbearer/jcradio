# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

if Rails.env.development?
    station = Station.create name: "Jingle Churro"

    queue = Song.create([
        {source: "Spotify", source_id: "bogus", title: "Interlude", artist: "Alt-J", album: "An Awesome Wave"}
    ])
    station.update songs: queue
end
