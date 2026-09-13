require 'rspotify/oauth'

spotify_client_id = ENV.fetch('SPOTIFY_CLIENT_ID')
spotify_client_secret = ENV.fetch('SPOTIFY_CLIENT_SECRET')

RSpotify.authenticate(spotify_client_id, spotify_client_secret)

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :spotify, spotify_client_id, spotify_client_secret,
          scope: 'playlist-modify-public user-modify-playback-state user-read-playback-state user-library-modify user-library-read'
end
