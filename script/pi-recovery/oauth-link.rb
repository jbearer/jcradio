require 'uri'

path = File.join(Dir.home, '.local/state/jcradio-player/player.log')
text = File.read(path)
url = text.scan(%r{https://accounts\.spotify\.com/authorize\?[^\s]+}).last
if url
  uri = URI(url)
  params = URI.decode_www_form(uri.query).to_h
  puts "OAuth redirect: #{params['redirect_uri']}"
  puts "OAuth scopes: #{params['scope']}"
  puts "Authorization URL: #{url}"
else
  puts 'No authorization link found; no raw logs displayed.'
end
