require 'rspotify'

# Spotify's 401 body changed from "The access token expired" to
# "Missing/invalid/expired access token", so RSpotify 2.9.2's message match never
# refreshes. Refresh on any 401 and retry once; other failures still raise.
module RSpotify
  class User
    def self.oauth_send(user_id, verb, path, *params)
      custom_headers = extract_custom_headers(params)
      headers = oauth_header(user_id).merge(custom_headers)
      params << headers
      RSpotify.send(:send_request, verb, path, *params)
    rescue RestClient::Unauthorized
      refresh_token(user_id)
      params[-1] = oauth_header(user_id).merge(custom_headers)
      RSpotify.send(:send_request, verb, path, *params)
    end
    private_class_method :oauth_send
  end
end
