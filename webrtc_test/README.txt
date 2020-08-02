WebRTC interface with UV4L on Raspberry Pi

Setup on the Pi

    Raspbian Image
        Raspbian Stretch

    Install UV4L
        https://www.linux-projects.org/uv4l/installation/
        
        $ curl http://www.linux-projects.org/listing/uv4l_repo/lpkey.asc | sudo apt-key add -

        Add line to  /etc/apt/sources.list
            deb http://www.linux-projects.org/listing/uv4l_repo/raspbian/stretch stretch main
        $ sudo apt-get update
        $ sudo apt-get install uv4l uv4l-raspidisp

    Set ALSA
        TODO: Figure out how default .asoundrc

        Add line to /etc/modules
            snd-aloop
        Add line to /etc/modprobe.d/alsa-base.conf
            options snd-aloop enable=1,1,1,1 index=1,2,3,4
        $ sudo reboot

        Create file /etc/asound.conf
            copy file from repo into this
            likely also copy/write to /home/pi/.asoundrc
        $ sudo service alsa-restore restart

        Define config file for uv4l
            copy config file to /etc/uv4l/uv4l-jcradio.conf

    Command to setup UV4L#1:
        /usr/bin/uv4l -f -k --sched-fifo --mem-lock --config-file=/etc/uv4l/uv4l-raspidisp.conf --driver raspidisp --driver-config-file=/etc/uv4l/uv4l-raspidisp.conf --server-option=--editable-config-file=/etc/uv4l/uv4l-raspidisp.conf --server-option=--port=8181 --server-option=--www-port=81 --server-option=--webrtc-recdevice-index=14
    Command to setup UV4L#2:
        /usr/bin/uv4l -f -k --sched-fifo --mem-lock --config-file=/etc/uv4l/uv4l-raspidisp.conf --driver raspidisp --driver-config-file=/etc/uv4l/uv4l-raspidisp.conf --server-option=--editable-config-file=/etc/uv4l/uv4l-raspidisp.conf --server-option=--port=8282 --server-option=--www-port=82 --server-option=--webrtc-recdevice-index=29

        --server-option=--webrtc-recdevice-index=44
        --server-option=--webrtc-recdevice-index=59


Ruby Install on Pi
    
    Actual, didn't use this (https://computers.tutsplus.com/tutorials/how-to-install-ruby-on-rails-on-raspberry-pi--cms-21421)

    Used this guide (rvm):
        Ruby version 2.4.9
        https://gorails.com/setup/ubuntu/16.04#ruby-rvm


Download Git Repo
    $ gem install bundler -v 1.7.0
    $ sudo apt-get install nodejs
    $ bundle install
    $ bundle update rspotify
    $ rake db:migrate
    $ rake db:setup
    $ rails server -b 0.0.0.0


Installing Rust for Rodio Backend for raspotify
    https://github.com/librespot-org/librespot/wiki/Compiling

    $ curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
    $ source ~/.cargo/env
    $ sudo apt-get install libsdl2-dev
    $ git clone https://github.com/librespot-org/librespot.git
    $ cargo build --release



Install VNC (for use with Ubuntu)
    http://mitchtech.net/vnc-setup-on-raspberry-pi-from-ubuntu/

Command to arecord
    arecord -D plughw:Loopback,0 -vv test.wav


Command to run librespot
    /usr/bin/librespot --name JCRadio --backend alsa --bitrate 160  --enable-volume-normalisation --linear-volume --initial-volume=100 -v
    Edit raspotify config
        sudo vim /etc/default/raspotify

    /usr/bin/librespot --name JCRadio --backend alsa --bitrate 160 --initial-volume=100 -v --disable-audio-cache


        Usage: librespot [options]

        Options:
            -c, --cache CACHE   Path to a directory where files will be cached.
                --disable-audio-cache 
                                Disable caching of the audio data.
            -n, --name NAME     Device name
                --device-type DEVICE_TYPE
                                Displayed device type
            -b, --bitrate BITRATE
                                Bitrate (96, 160 or 320). Defaults to 160
                --onevent PROGRAM
                                Run PROGRAM when playback is about to begin.
            -v, --verbose       Enable verbose output
            -u, --username USERNAME
                                Username to sign in with
            -p, --password PASSWORD
                                Password
                --proxy PROXY   HTTP proxy to use when connecting
                --ap-port AP_PORT
                                Connect to AP with specified port. If no AP with that
                                port are present fallback AP will be used. Available
                                ports are usually 80, 443 and 4070
                --disable-discovery 
                                Disable discovery mode
                --backend BACKEND
                                Audio backend to use. Use '?' to list options
                --device DEVICE Audio device to use. Use '?' to list options if using
                                portaudio or alsa
                --mixer MIXER   Mixer to use (alsa or softmixer)
            -m, --mixer-name MIXER_NAME
                                Alsa mixer name, e.g "PCM" or "Master". Defaults to
                                'PCM'
                --mixer-card MIXER_CARD
                                Alsa mixer card, e.g "hw:0" or similar from `aplay
                                -l`. Defaults to 'default'
                --mixer-index MIXER_INDEX
                                Alsa mixer index, Index of the cards mixer. Defaults
                                to 0
                --initial-volume VOLUME
                                Initial volume in %, once connected (must be from 0 to
                                100)
                --zeroconf-port ZEROCONF_PORT
                                The port the internal server advertised over zeroconf
                                uses.
                --enable-volume-normalisation 
                                Play all tracks at the same volume
                --normalisation-pregain PREGAIN
                                Pregain (dB) applied by volume normalisation
                --linear-volume 
                                increase volume linear instead of logarithmic.
                --autoplay      autoplay similar songs when your music ends.


Install DarkIce and IceCast2
    https://maker.pro/raspberry-pi/projects/how-to-build-an-internet-radio-station-with-raspberry-pi-darkice-and-icecast


wget https://github.com/x20mar/darkice-with-mp3-for-raspberry-pi/blob/master/darkice_1.0.1-999~mp3+1_armhf.deb?raw=true
mv darkice_1.0.1-999~mp3+1_armhf.deb?raw=true darkice_1.0.1-999~mp3+1_armhf.deb
sudo apt-get install libmp3lame0 libtwolame0
sudo dpkg -i darkice_1.0.1-999~mp3+1_armhf.deb