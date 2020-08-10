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

end
