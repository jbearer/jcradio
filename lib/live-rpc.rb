module LiveRPC
    @servers = {}
        # Map from UIDs to Server instances.
    @lock = Mutex.new
        # Lock protecting `servers`.

    # Start a new RPC server with the given `id`.
    #
    # The server will receive RPC calls from clients (via `call` and
    # `broadcast`) and forward them to the given I/O stream (which should
    # probably be an ActionController::Live stream).
    #
    # If a server with this `id` already exists, it will be closed. Queued
    # messages which have not yet been processed by the old server will be
    # processed, in order, by the new server, before any new events sent to the
    # new server.
    #
    # This function will not return until the server is closed down, either
    # because the other end of `stream` disconnects, or because a new server is
    # created with the same `id`. Therefore, this function should not be called
    # from the main thread. If `stream` is an ActionController::Live stream,
    # this function should be called from the thread dedicated to handling the
    # livestream request.
    def self.serve(id, stream)
        server = @lock.synchronize do
            queue = (@servers.key? id) ? @servers[id].close : []
                # If there is an old server, close it down and take its leftover
                # unprocessed events.
            @servers[id] = Server.new stream, queue
            @servers[id]
        end

        server.serve
    end

    # Check if there is an active server with the given id.
    def self.server?(id)
        @lock.synchronize do
            @servers.key? id and @servers[id].serving?
        end
    end

    # Make an RPC call to a server with the given ID.
    def self.call(id, function, args)
        @lock.synchronize do
            @servers[id].call(function, args) if @servers.key? id
        end
    end

    # Make an RPC call to all active servers.
    def self.broadcast(function, args)
        @lock.synchronize do
            @servers.each_value do |server|
                server.call(function, args)
            end
        end
    end

    def self.close(id)
        @lock.synchronize do
            if @servers.key? id
                @servers[id].close
                @servers.delete id
            end
        end
    end

    at_exit do
        # Close all the active servers so that their livestream requests will
        # finish, and the server can actually shut down.
        @lock.synchronize do
            @servers.each_value do |server|
                server.close
            end
        end
    end

    class Server
        def initialize(stream, queue=[])
            @sse = ActionController::Live::SSE.new stream, event: "live-rpc"
                # I/O stream where we'll send events on behalf of clients.
            @queue = queue
                # Queue where we'll receive messages from clients.
            @lock = Mutex.new
                # Lock protecting `queue`.
            @queue_signal = ConditionVariable.new
                # Signal indicating the queue is non-empty.
            @serving = false
        end

        def serve
            @serving = true

            while true
                @lock.synchronize do
                    # Wait for a message.
                    while @queue.empty?
                        @queue_signal.wait @lock
                    end

                    # Process the message, but do not remove it from the queue
                    # yet. We only want to pop the message off the queue after
                    # we have successfully process it. If we fail to send the
                    # message to the SSE stream because the remote session has
                    # disconnected, we want to keep the message on the queue so
                    # we can resend it if the remote later reconnects.
                    msg = @queue[0]

                    if msg.nil?
                        return
                    end

                    # Send the message to the remote session.
                    @sse.write msg

                    # If that didn't throw a ClientDisconnected exception, then
                    # we have successfully processed the message. We can now
                    # dequeue it.
                    @queue.shift
                end
            end
        ensure
            @serving = false
            @sse.close
        end

        def serving?
            @serving
        end

        def call(function, args)
            @lock.synchronize do
                @queue.push({ function: function, args: args })
                @queue_signal.signal
            end
        end

        def close
            @lock.synchronize do
                # Return everything on the queue right now, so the caller can
                # process these leftover messages somehow.
                leftover = @queue

                # Send a nil message to cause the server to exit.
                @queue = [nil]
                @queue_signal.signal

                leftover
            end
        end
    end
end
