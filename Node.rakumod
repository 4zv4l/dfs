use JSON::Tiny;
use File::Find;
use Base64;
use Log::Async;

unit class Node;

has            %.nodes is rw;   #= neighbour nodes (dynamic)
has            %index;          #= files index (dynamic)
has            $.path;          #= path to share with nodes
has            $.lhost;         #= listening address
has            $.lport;         #= listening port
has            %skip-path;      #= path to skip watch event (dynamic)
has            %watched;        #= directories being watched (dynamic)

# build %index from $path
method TWEAK {
    for find(:dir($!path), :type('file')) -> $file {
        %index{$file.IO.relative($!path.IO.parent)} = $file.IO.changed.to-posix[0];
    }
}

# send to all known nodes our index and our nodes
method announce() {
    race for %!nodes.keys -> $node-laddr {
        IO::Socket::Async.connect(|$node-laddr.split(':')).then: -> $promise {
            info "sending index to $node-laddr";
            try given $promise.result {
                .print(to-json({:$!lhost, :$!lport}) ~ "\n");
                .print("ANNOUNCE {to-json({:index(%index), :nodes(%!nodes)})}\n");
                .close;
            } // (%!nodes{$node-laddr}:delete);
        }
    }
}

# get request from other nodes
method listen() {
    my $server = IO::Socket::Async.listen($!lhost, $!lport).tap: -> $conn {
        debug "Connection received !";
        my $input               = $conn.Supply.lines.Channel;
        my $node-laddr          = from-json $input.receive;
        my %remote              = :addr("{$conn.peer-host}:{$conn.peer-port}"),
                                  :laddr($node-laddr<lhost lport>.join(':')),
                                  :lhost($node-laddr<lhost>),
                                  :lport($node-laddr<lport>);
        %!nodes{%remote<laddr>} = now.to-posix[0];
        info "Connection: %remote<addr> ::: %remote<laddr>";

        given $input.receive {

            # Nodes send their index/nodes when joining or on file update
            when /ANNOUNCE \s+ $<json> = (.+)/ {
                my ($remote-index, $remote-nodes) = from-json($<json>)<index nodes>;
                info "%remote<addr> sent index: {$remote-index.raku}, sent nodes: {$remote-nodes.raku}";
                # update nodes
                %!nodes = |%!nodes, |$remote-nodes;
                debug "Deleting $!lhost:$!lport from {%!nodes.raku}";
                %!nodes{"$!lhost:$!lport"}:delete;
                debug "nodes: {%!nodes.raku}";
                # update index/files
                for $remote-index.kv -> $path, $time {
                    debug "checking: $path";
                    if !%index{$path} or (%index{$path}:exists and Instant.from-posix(%index{$path}) < Instant.from-posix($time)) {
                        %index{$path} = $time;
                        self.request($path, :host(%remote<lhost>), :port(%remote<lport>));
                    }
                }
                debug "Done with announce received by %remote<addr>";
            }

            # Nodes request a file for download
            when /REQUEST \s+ $<path> = (.+)/ {
                info "%remote<addr> request: $<path>";
                await $conn.print: encode-base64($<path>.IO.slurp(:bin), :str);
                await $conn.print: "\n";
                debug "done sending $<path>";
            }
        };
    }
    info "Listening on {join ':', await $server.socket-host, $server.socket-port}";
}

# download $path from $host:$port
method request($path, :$host, :$port) {
    # avoid sending index after downloading file (which triggers watch event)
    $path.IO.e ?? (%skip-path{$path} += 1) !! (%skip-path{$path} += 2);
    info "Asking $host:$port for $path";
    IO::Socket::Async.connect($host, $port).then: -> $promise {
        try given $promise.result {
            .print(to-json({:$!lhost, :$!lport}) ~ "\n");
            .print("REQUEST $path\n");
            $path.IO.dirname.IO.mkdir;
            $path.IO.spurt(decode-base64(.Supply.lines.Channel.receive, :bin));
            debug "$path: has been downloaded";
        } // (error "Oops, couldnt download file");
    }
}

# Watch $path and update nodes when something happen
method watch($dir) {
    $dir.IO.watch.act: {
        my $path = .path.IO.relative($!path.IO.parent);
        if $path.IO.d {
            self.watch($path) unless %watched{$path};
            %watched{$path} = now.to-posix[0];
            debug "Now watching: $path";
        } elsif (%skip-path{$path}:exists and %skip-path{$path} > 0) or (!%index{$path} and .event == FileRenamed) {
            debug "Skipped: $path => {.event}";
            %skip-path{$path} -= 1;
        } elsif $path.IO.f {
            info "$path: {.event}";
            %index{$path} = $path.IO.changed.to-posix[0];
            self.announce;
        }
    }
}

method serve {
    self.announce;
    self.listen;
    self.watch($!path);
    for find(:dir($!path), :type('dir')) -> $dir {
        self.watch($dir);
    }
}
