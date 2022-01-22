module StationsHelper
    def self.get_progress_ms
        url = "me/player"
        response = RSpotify::User.oauth_get($spotify_user.id, url)

        if not response['is_playing']
            return 999999999
        end

        return response["progress_ms"]
    end

    def self.set_device(device_id)
        url = "me/player"
        params = {"device_ids": [device_id]}
        RSpotify::User.oauth_put($spotify_user.id, url, params.to_json)
    end
end
