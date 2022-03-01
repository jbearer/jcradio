module SongsHelper

    def msToMinSec(ms)
        seconds = ms / 1000
        return "%d:%02d" % [seconds / 60, seconds % 60]
    end

    ######################
    ## CHOOSING LETTERS
    ######################

    def self.calculate_next_letter(title)
        # TODO: would be nice if numbers worked
        begin
          words = normalize_title(title)

          if words.count == 0 then
            return random_letter()

          elsif words.count == 1 then
            # return the 4th-to-last letter
            word = words[0].chars
            idx = (4 % word.count) * -1
            return word[idx]

          else
              # return the first word of the last letter
              last_word = words[-1]
              return last_word[0]
          end

        rescue
          return random_letter()
        end
    end

    def self.first_letter(title)

        normalized = normalize_title(title)

        if normalized.count == 0 then
            return "_"
        elsif normalized[0].length == 0 then
            return "_"
        else
            return normalized[0][0]
        end
    end

    # return an array of words
    def self.normalize_title(title)
      title = title.upcase

      # Delete Parenthesis phrases
      open_paran_i = title.index("(")
      close_paran_i = title.index(")")
      if open_paran_i and close_paran_i
        title = title[0..open_paran_i]+title[close_paran_i..-1]
      end

      # Strip after hyphens
      hyphen_i = title.index(/[-–]/)
      if hyphen_i
        title = title[0..hyphen_i]
      end

      # Remove all non-letter characters
      title.gsub! /[^A-Z ]/, ""
      words = title.split

      if words.count == 0 then
        return []
      end

      articles = ["THE", "A", "AN", "UN", "UNE", "LE", "LES"]
      for art in articles do
        if words[0] == art then
            words = words.drop(1)
            break
        end
      end
      return words
    end

    def self.random_letter
      puts "Error calculating next letter. Choosing a random letter"
      alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".chars
      return alphabet.sample
    end

    def self.get_or_create_from_spotify_record(songs, persist=false)
      # songs is a list of spotify_songs

      # index the spotify songs by their ids
      spotify_ids = songs.map{|s| [s.id, s]}.to_h

      # a list of Song objects that match the spotify songs
      matches = Song.all.select{|item| spotify_ids.key? item.source_id}
                  .map{|s| [s.source_id, s]}.to_h

      results = []

      songs.each do |s|

        if matches.key? s.id then
          result = matches[s.id]
          #   if result.first_letter != SongsHelper.first_letter(s.name) then
          #       result.update first_letter: SongsHelper.first_letter(s.name)
          #   end
          #   if result.next_letter != SongsHelper.calculate_next_letter(s.name) then
          #       result.update next_letter: SongsHelper.calculate_next_letter(s.name)
          #   end
          # end

          # TODO: Why does this take such a stupid amount of time?
          # if (not result.preview_url) then
          #   if s.preview_url then
          #     result.update preview_url: s.preview_url
          #   end
          # end
          results.push(matches[s.id])
        else
          data = {
            title: s.name,
            artist: s.artists.first.name,
            album: s.album.name,
            source: "Spotify",
            source_id: s.id,
            uri: s.uri,
            duration: s.duration_ms,
            first_letter: SongsHelper.first_letter(s.name),
            next_letter: SongsHelper.calculate_next_letter(s.name),
            preview_url: s.preview_url,
          }

          if persist then
            results.push(Song.create data)
          else
            results.push(Song.new data)
          end
        end
      end

      return results
    end

end
