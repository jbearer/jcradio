release = File.join(Dir.home, '.local/share/jcradio-player/raspotify-0.48.2/librespot')
Dir.glob('/proc/[0-9]*/cmdline').each do |path|
  begin
    next unless File.binread(path).split("\0").include?(release)
    process_id = Integer(path.split('/')[2])
    Process.kill('TERM', process_id)
    puts "Sent TERM to private player PID #{process_id}"
  rescue Errno::ENOENT, Errno::EACCES, Errno::ESRCH
  end
end
