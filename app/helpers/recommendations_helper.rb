module RecommendationsHelper

    def features
        [
            {name: "acousticness", min: 0, max: 1, scale: 100},
            {name: "danceability", min: 0, max: 1, scale: 100},
            {name: "duration_ms", min: 0, max: 600000, scale: 1},
            {name: "energy", min: 0, max: 1, scale: 100},
            {name: "instrumentalness", min: 0, max: 1, scale: 100},
            {name: "key", min: 0, max: 11, scale: 1},
            {name: "liveness", min: 0, max: 1, scale: 100},
            # #{name: "loudness"}
            {name: "mode", min: 0, max: 1, scale: 1},
            {name: "popularity", min: 0, max: 100, scale: 1},
            {name: "speechiness", min: 0, max: 1, scale: 100},
            {name: "tempo", min: 0, max: 200, scale: 1},
            {name: "time_signature", min: 1, max: 16, scale: 1},
            {name: "valence", min: 0, max: 1, scale: 100}
        ]
    end

end
