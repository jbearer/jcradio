module StationsHelper
    def self.get_progress_ms
        if $spotify_user.nil?
            return 999999999
        end

        url = "me/player"
        response = RSpotify::User.oauth_get($spotify_user.id, url)

        if !response.nil? and response['is_playing']
            return response["progress_ms"]
        end

        return 999999999

    end

    def self.set_device(device_id)
        url = "me/player"
        params = {"device_ids": [device_id]}
        RSpotify::User.oauth_put($spotify_user.id, url, params.to_json)
    end
end

################ Background process to update song title
# https://blog.appsignal.com/2019/04/02/background-processing-system-in-ruby.html
module Magique
    module Worker
        def self.included(base)
            base.extend(ClassMethods)
        end

        module ClassMethods
            def perform_now(*args)
                new.perform(*args)
            end
            def perform_async(*args)
                $the_background_thread = Thread.new { new.perform(*args) }
            end
        end

        def perform(*)
            raise NotImplementedError
        end
    end
end

class TitleExtractorWorker < ApplicationController
    include Magique::Worker

    # Background thread which monitors the current playing song

    # If no song is playing, sleep until woken up
    # If the current song is different from the last song, update the song,
    #   Then sleep until you calculate it to be over
    # If the current song is the same as the last song, sleep until it's over
    def perform(station)

        last_song = nil
        while true
            begin
                player = $spotify_user.player
                if not player or not player.playing?
                    sleep   # until awoken
                    next
                end

                curr_song = player.currently_playing
                if (not last_song) or (curr_song.id != last_song.id) then
                    # We have a new song
                    last_song = curr_song

                    logger.error("***************************************")
                    logger.error("We have a new song")
                    logger.error("***************************************")

                    # Update the queue with the new song
                    Station.find(1).next_song(Song.get("Spotify", curr_song.id))
                    Station.find(1).update_timing_stats()
                    logger.error("***************************************")
                    logger.error("called next_song and update_timing")
                    logger.error("***************************************")
                end

                # If one song in queue, notify next user
                if Station.find(1).queue_max - Station.find(1).queue_pos == 0
                    if $notify_laggard_user
                        $notify_laggard_user = false # unset the flag
                        next_user = Station.find(1).users.order(:position)[0]
                        if next_user.username != "Buddy"
                            # Notify the next user that it's their turn to pick a song.
                            broadcast :push, "Wake up #{next_user.username}, you have a #{$the_next_letter}"
                            # logger.info("****************************")
                            # logger.info("notify user: #{next_user.username}")
                            # logger.info("****************************")
                        end
                    end
                else
                    $notify_laggard_user = true
                end

                time_diff = Station.find(1).time_till_next_song().to_f / 1000 / 10
                # time_diff = 5

            rescue => e
                Rails.logger.error e.message
                e.backtrace.each { |line| Rails.logger.error line }
                time_diff = 5
            end

            # Lowerbound at 1 so we don't spam spotify tooo much
            sleep_time = time_diff > 1 ? time_diff : 1
            sleep(sleep_time)
        end
    end
end
#device id for my phone for testing
$daniels_phone="11b8da8cb3a8144bda76d1f50599ed0b98a09ee1"
