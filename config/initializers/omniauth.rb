
require 'rspotify/oauth'
require 'rspotify'

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :spotify, "b0f411963a924c1497bae046d67e03c9", "d4216a91bd1249e9aee62c3062c18a34", scope: 'user-read-private user-read-playback-state user-modify-playback-state user-read-email playlist-modify-public user-library-read user-library-modify'
end

RSpotify.authenticate("b0f411963a924c1497bae046d67e03c9", "d4216a91bd1249e9aee62c3062c18a34")
