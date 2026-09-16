require "yaml"
require "json"
require "rspotify"

# The Spotify logins this process holds.
#
# The radio account is the shared Spotify user whose player feeds the stream. It is saved
# to a restore file so it survives restarts; RSpotify refreshes the stale token on the
# first call. Listeners may also link personal accounts, which live in memory only and
# are keyed by username because Buddy's taste settings refer to listeners by name.
#
# Lives in lib/ (not autoloaded) so this state survives development-mode code reloads.
module SpotifyAccounts
    RADIO_DISPLAY_NAME = "JC Radio"
    DEFAULT_RADIO_DEVICE_ID = "d94494a49582daf871e6a18d955ea69946163d6f"
    LIBRARY_TTL = 24 * 60 * 60 # seconds between full library fetches
    LIBRARY_PAGE = 50          # Spotify's maximum page size for me/tracks
    NOT_PLAYING_MS = 999_999_999

    @radio = nil
    @linked = {}    # username => RSpotify::User
    @libraries = {} # username => [fetched_at, tracks]
    @lock = Mutex.new

    class << self
        #
        # Radio account
        #

        attr_accessor :radio

        def radio_device_id
            ENV.fetch("JCRADIO_SPOTIFY_DEVICE_ID") { DEFAULT_RADIO_DEVICE_ID }
        end

        def restore_file
            ENV.fetch("JCRADIO_SPOTIFY_RESTORE_FILE") { File.join(Dir.home, "jcradio", ".nothingtoseehere.yml") }
        end

        def sign_in_radio(account)
            File.write(restore_file, account.to_hash.to_yaml)
            self.radio = account
        end

        def sign_out_radio
            File.delete(restore_file) if File.exist?(restore_file)
            self.radio = nil
        end

        # Load the account saved by the last sign-in, if any. Returns it or nil.
        def restore_radio
            return nil unless File.exist?(restore_file)
            # The file is written by sign_in_radio and contains RSpotify/OmniAuth objects,
            # which YAML.safe_load rejects; treat it as a credential file, not user input.
            self.radio = RSpotify::User.new(YAML.load_file(restore_file))
        end

        # Milliseconds into the current track, or NOT_PLAYING_MS when idle.
        def radio_progress_ms
            return NOT_PLAYING_MS unless radio
            response = RSpotify::User.oauth_get(radio.id, "me/player")
            if response && response["is_playing"]
                response["progress_ms"]
            else
                NOT_PLAYING_MS
            end
        end

        def transfer_radio_playback(device_id = radio_device_id)
            RSpotify::User.oauth_put(radio.id, "me/player", { device_ids: [device_id] }.to_json)
        end

        # IDs of the Connect devices Spotify currently lists for the radio account.
        def radio_device_ids
            return [] unless radio
            response = RSpotify::User.oauth_get(radio.id, "me/player/devices")
            json = RSpotify.raw_response ? JSON.parse(response) : response
            (json["devices"] || []).map { |device| device["id"] }
        end

        def radio_device_present?
            radio_device_ids.include?(radio_device_id)
        end

        #
        # Listeners' personal accounts
        #

        def link(user, account)
            @lock.synchronize do
                @linked[user.username] = account
                @libraries.delete(user.username)
            end
        end

        def unlink(user)
            @lock.synchronize do
                @linked.delete(user.username)
                @libraries.delete(user.username)
            end
        end

        def linked(user)
            return nil unless user
            @lock.synchronize { @linked[user.username] }
        end

        def linked?(user)
            !linked(user).nil?
        end

        def linked_usernames
            @lock.synchronize { @linked.keys }
        end

        # The listener's saved tracks, fetched at most once per LIBRARY_TTL.
        def library(user)
            account = linked(user)
            return [] unless account

            cached = @lock.synchronize { @libraries[user.username] }
            return cached[1] if cached && Time.now < cached[0] + LIBRARY_TTL

            tracks = fetch_library(account)
            @lock.synchronize { @libraries[user.username] = [Time.now, tracks] }
            tracks
        end

        def expire_library(user)
            @lock.synchronize { @libraries.delete(user.username) }
        end

        def library_size(account)
            response = RSpotify::User.oauth_get(account.id, "me/tracks?limit=1&offset=0")
            json = RSpotify.raw_response ? JSON.parse(response) : response
            json["total"]
        end

        private

        def fetch_library(account)
            total = library_size(account)
            tracks = []
            offset = 0
            while offset < total
                tracks.concat(account.saved_tracks(limit: LIBRARY_PAGE, offset: offset))
                offset += LIBRARY_PAGE
            end
            tracks
        end
    end
end
