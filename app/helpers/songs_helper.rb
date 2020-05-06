module SongsHelper

    def msToMinSec(ms)
        seconds = ms / 1000
        return "%d:%02d" % [seconds / 60, seconds % 60]
    end
end
