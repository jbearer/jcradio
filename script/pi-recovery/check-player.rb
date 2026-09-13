require 'json'

release = File.join(Dir.home, '.local/share/jcradio-player/raspotify-0.48.2/librespot')
processes = Dir.glob('/proc/[0-9]*/cmdline').select do |path|
  begin
    File.binread(path).split("\0").include?(release)
  rescue Errno::ENOENT, Errno::EACCES
    false
  end
end
puts "Private player PIDs: #{processes.map { |path| path.split('/')[2] }.join(', ')}"
path = File.join(Dir.home, '.local/state/jcradio-player/player.log')
if File.file?(path)
  text = File.read(path)
  puts "Log bytes: #{text.bytesize}"
  patterns = {
    'version' => /librespot [0-9]+\.[0-9]+\.[0-9]+ [a-f0-9]+/,
    'discovery' => /(?:[Dd]iscovery|[Zz]eroconf|mDNS)/,
    'authentication' => /(?:Authenticated|Authentication failed|BadCredentials|No credentials)/,
    'audio' => /(?:ALSA|alsa|plughw:Loopback,1)/,
    'error' => /(?:ERROR|panicked|Connection refused|Permission denied|No such file or directory)/
  }
  patterns.each { |name, pattern| puts "#{name}: #{text.scan(pattern).uniq.join(', ')}" }
end
