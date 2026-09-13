#!/usr/bin/env ruby
# Summarize Rails request timings from a development/production log.
# Usage: ruby script/perf/log-timings.rb log/development.log [since_date=YYYY-MM-DD]
# Pairs "Processing by Controller#action" with the next "Completed ... in Xms" line.
# Only prints aggregate numbers per action; never prints query strings or params.

path = ARGV[0] || "log/development.log"
since = ARGV[1]

current = nil
current_fmt = nil
current_date = nil
stats = Hash.new { |h, k| h[k] = { total: [], views: [], ar: [] } }

File.foreach(path) do |line|
  if line.start_with?("Started ")
    m = line.match(/ at (\d{4}-\d{2}-\d{2})/)
    current_date = m && m[1]
  elsif line.start_with?("Processing by ")
    m = line.match(/Processing by (\S+) as (\S+)/)
    current = m && m[1]
    current_fmt = m && m[2]
  elsif line.start_with?("Completed ") && current
    next if since && current_date && current_date < since
    m = line.match(/Completed (\d+) .* in (\d+)ms(?: \(Views: ([\d.]+)ms \| ActiveRecord: ([\d.]+)ms\))?/)
    next unless m
    key = "#{current} (#{current_fmt})"
    stats[key][:total] << m[2].to_i
    stats[key][:views] << m[3].to_f if m[3]
    stats[key][:ar] << m[4].to_f if m[4]
    current = nil
  end
end

def pct(arr, p)
  return nil if arr.empty?
  s = arr.sort
  s[[(s.length * p).floor, s.length - 1].min]
end

rows = stats.map do |key, s|
  t = s[:total]
  [key, t.length, pct(t, 0.5), pct(t, 0.9), t.max, pct(s[:views], 0.5), pct(s[:ar], 0.5)]
end
rows.sort_by! { |r| -(r[2] || 0) * r[1] }

puts "%-52s %6s %8s %8s %8s %9s %8s" % %w[action n p50ms p90ms maxms views50 ar50]
rows.each do |r|
  puts "%-52s %6d %8s %8s %8s %9s %8s" % r.map { |v| v.nil? ? "-" : v }
end
