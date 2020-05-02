module SongsHelper

    def msToMinSec(ms)
        seconds = ms / 1000
        return "%d:%d" % [seconds / 60, seconds % 60]
    end
end
