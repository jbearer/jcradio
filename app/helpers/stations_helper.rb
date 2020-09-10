module StationsHelper
    def self.get_progress_ms
        url = "me/player"
        response = RSpotify::User.oauth_get($spotify_user.id, url)

        return response["progress_ms"]
    end

end
