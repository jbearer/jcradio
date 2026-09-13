#!/usr/bin/env ruby
# Structural checks for docs/**/*.md per docs/DOCS_STYLE_GUIDE.md. Ruby 2.4 compatible.
Dir.chdir(File.expand_path('..', __dir__))

files = Dir['docs/**/*.md'].reject { |file| file.end_with?('DOCS_STYLE_GUIDE.md') }
links = 0

files.each do |file|
  lines = File.read(file).lines
  stack = []
  fenced = false

  lines.each_with_index do |line, index|
    if line.lstrip.start_with?('```')
      abort "Missing fence language: #{file}:#{index + 1}" if !fenced && line.strip == '```'
      fenced = !fenced
      next
    end
    next if fenced

    if (match = line.match(/\A( *)- <details(?: open)?> <summary> <b>.+<\/b> <\/summary>\s*\z/))
      abort "Missing blank after summary: #{file}:#{index + 1}" unless lines[index + 1].to_s.strip.empty?
      stack << match[1].length + 2
    elsif line.strip == '</details>'
      abort "Misaligned details: #{file}:#{index + 1}" unless stack.pop == line[/\A */].length
    end
  end
  abort "Unbalanced blocks: #{file}" unless stack.empty? && !fenced

  lines.join.scan(/\[[^\]]+\]\(([^)]+)\)/).flatten.each do |target|
    next if target =~ /\A(?:https?:|#)/
    path = File.expand_path(target.split('#').first, File.dirname(file))
    abort "Broken link: #{file}:#{target}" unless File.exist?(path)
    links += 1
  end
end

abort 'Missing Pi overview navigation' unless File.read('docs/README.md').include?('(pi-overview.md)')
abort 'Missing network navigation' unless File.read('docs/pi/README.md').include?('(network-setup.md)')
puts "#{files.length} documentation pages: details, fences, navigation, and #{links} local links OK"
