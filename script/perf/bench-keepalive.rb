# Verifies Spotify connection reuse inside a booted app (initializers loaded):
#   ssh jcradio-pi 'bash -lic "cd ~/jcradio && bin/rails runner script/perf/bench-keepalive.rb"'
# Unauthenticated GETs (401) only; no token, no writes.

url = "https://api.spotify.com/v1/me/player"
puts "pool patched: #{RestClient::Request.ancestors.include?(JCRadio::RestClientKeepAlive)}"
5.times do |i|
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  begin
    RestClient.get(url)
  rescue RestClient::Unauthorized
  end
  ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000).round
  puts "call #{i + 1}: #{ms} ms  idle pooled connections: #{JCRadio::HttpConnectionPool.idle_count('api.spotify.com', 443)}"
end
