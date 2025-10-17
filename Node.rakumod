use JSON::Tiny;
use File::Find;
use Base64;

unit class Node;

has            %.nodes is rw;
has            %index;
has            $.path;
has            $.lhost;
has            $.lport;
has            %skip-path;

# build %index from $path
method TWEAK {
    for find(:dir($!path), :type('file')) -> $file {
        %index{$file.IO.relative($!path.IO.parent)} = $file.IO.modified.to-posix[0];
    }
}

# send to all known nodes our current index
method announce() {
    await race for %!nodes.keys -> $node-laddr {
        IO::Socket::Async.connect(|$node-laddr.split(':')).then: -> $promise {
            say "sending index to $node-laddr";
            try given $promise.result {
                .print(to-json({:$!lhost, :$!lport}) ~ "\n");
                .print("INDEX {to-json %index}\n");
                .close;
            } // (%!nodes{$node-laddr}:delete);
        }
    }
    say "done announcing";
}

# get request from other nodes
method listen() {
    my $server = IO::Socket::Async.listen($!lhost, $!lport).tap: -> $conn {
        say "Connection received !";
        my $input               = $conn.Supply.lines.Channel;
        my $node-laddr          = from-json $input.receive;
        my %remote              = :addr("{$conn.peer-host}:{$conn.peer-port}"),
                                  :laddr($node-laddr<lhost lport>.join(':')),
                                  :lhost($node-laddr<lhost>),
                                  :lport($node-laddr<lport>);
        %!nodes{%remote<laddr>} = now;
        say "Connection: %remote<addr> ::: %remote<laddr>";

        start given $input.receive {

            # Nodes send their index when joining or file update
            when /INDEX \s+ $<json-index> = (.+)/ {
                my %remote-index = from-json $<json-index>;
                say "%remote<addr> sent index: {%remote-index.raku}";
                for %remote-index.kv -> $path, $time {
                    say "checking: $path";
                    if !%index{$path} or (%index{$path}:exists and Instant.from-posix(%index{$path}) < Instant.from-posix($time)) {
                        %index{$path} = $time;
                        self.request($path, :host(%remote<lhost>), :port(%remote<lport>));
                    }
                }
                say "Done with index received by %remote<addr>";
            }

            # Nodes request a file for download
            when /REQUEST \s+ $<path> = (.+)/ {
                say "%remote<addr> request: $<path>";
                await $conn.print: encode-base64($<path>.IO.slurp(:bin), :str);
                await $conn.print: "\n";
                say "done sending $<path>";
            }
        };
    }
    say "Listening on {join ':', await $server.socket-host, $server.socket-port}";
}

method request($path, :$host, :$port) {
    # avoid sending index after downloading file (which triggers watch event)
    $path.IO.e ?? (%skip-path{$path} += 1) !! (%skip-path{$path} += 2);
    say "Asking $host:$port for $path";
    given IO::Socket::INET.new(:$host, :$port) {
        .print(to-json({:$!lhost, :$!lport}) ~ "\n");
        .print("REQUEST $path\n");
        $path.IO.dirname.IO.mkdir;
        $path.IO.spurt(decode-base64(.get, :bin));
        say "$path: has been downloaded";
    }
}

# Watch $path and update nodes when something happen
method watch() {
    $!path.IO.watch.act: {
        my $path = .path.IO.relative($!path.IO.parent);
        if (%skip-path{$path}:exists and %skip-path{$path} > 0) or (!%index{$path} and .event == FileRenamed) {
            %skip-path{$path} -= 1;
        } elsif $path.IO.f {
            say "$path: {.event}";
            %index{$path} = $path.IO.modified.to-posix[0];
            self.announce;
        }
    }
}

method serve {
    self.announce;
    self.listen;
    self.watch;
}
