
begin
  require 'rspotify/oauth'

  RSpotify.authenticate("b0f411963a924c1497bae046d67e03c9", "d4216a91bd1249e9aee62c3062c18a34")

  Rails.application.config.middleware.use OmniAuth::Builder do
    provider :spotify, "b0f411963a924c1497bae046d67e03c9", "d4216a91bd1249e9aee62c3062c18a34",
            scope: 'playlist-modify-public user-modify-playback-state user-read-playback-state user-library-modify'
  end
rescue RestClient::BadRequest => e
  puts "=======\n" \
       "Missing Spotify client credentials. Please enter SPOTIFY_CLIENT_ID\n" \
       "and SPOTIFY_CLIENT_SECRET in config/env.yml.\n" \
       "======="
end
