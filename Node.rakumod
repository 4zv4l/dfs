use JSON::Tiny;
use File::Find;
use Base64;

unit class Node;

has            %.nodes is rw;
has            %index;
has            $.path;
has            $.lhost;
has            $.lport;

# build %index from $path
method TWEAK {
    for find(:dir($!path), :type('file')) -> $file {
        %index{$file} = $file.IO.modified;
    }
}

# send to all known nodes our current index
method announce() {
    race for %!nodes.keys -> $addr {
        IO::Socket::Async.connect(|$addr.split(':')).then: -> $promise {
            given $promise.result {
                say "Connected !";
                .print("INDEX {to-json %index}");
                .close;
            }
        }
    }
}

# get request from other nodes
method listen() {
    IO::Socket::Async.listen($!lhost, $!lport).tap: -> $conn {
        my $node-addr = "{$conn.peer-host}:{$conn.peer-port}";
        %!nodes{$node-addr} = now;
        say "New node on {$node-addr}";

        my $input = $conn.Supply.lines.Channel;
        start loop {
            try given $input.receive {

                # Nodes send their index when joining or file update
                when /INDEX \s+ $<json-index>=(.+)/ {
                    my %remote-index = from-json $<json-index>;
                    for %remote-index.kv -> $path, $time {
                        # if does not exist in index or is older than remote-index (download)
                        if !%index{$path} or (%index{$path}:exists and %index{$path} < $time) {
                            %index{$path} = $time;
                            $conn.print("REQUEST $path\n");
                            $path.IO.spurt(decode-base64($input.receive, :bin));
                        }
                    }
                }

                # Nodes request a file for download
                when /REQUEST \s+ $<path>=(.+)/ {
                    $<path>.IO.open(:bin).Supply(:size(64*1024*1024)).tap: -> $chunk {
                        $conn.write(encode-base64($chunk, :bin));
                    }
                    $conn.print("\n");
                }

            } // last;
        }

        # remove node if disconnect
        LAST { %!nodes{$node-addr}:delete }
    }
}

# Watch $path and update nodes when something happen
method watch() {
    $!path.IO.watch.act: {
        say "{.gist}";
        %index{.path} = now;
        self.announce;
    }
}

method serve {
    self.announce;
    self.listen;
    self.watch;
}
