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