unit class Node;

has Set[Node]  $neighbours;
has            %.index is rw;
has            @.paths;
has            $.lhost;
has            $.lport;

method TWEAK {
    @.paths .= map: *.IO;
    while @.paths -> $path {
        for @.paths.pop.dir -> $entry {
            %.index{$entry} = 1 if $entry.f;
            @.paths.push($entry) if $entry.d;
        }
    }

    # neighbours loading
}

method announce() {
    for $neighbours.keys -> $node {
        IO::Socket::Async.udp.print-to: $node.lhost, $node.lport, "INDEX {to-json %.index}";
    }
}

method listen() {
    my $udp = IO::Socket::Async.bind-udp($.lhost, $.lport);
    $udp.Supply(:datagram).tap: {
        my ($rhost, $rport, $msg) = .hostname, .port, .data.gist;
        given $msg {
            when /INDEX\s+(.+)/ {
                %.index = |%.index, |(from-json $0);
                $neighbours{"{$rhost}"{$rport}}++;
            }
            when /REQUEST\s+(.+)/ {
                given IO::Socket::INET.new(:host($rhost), :port($rport)) {
                    .write: $0.IO.slurp(:bin);
                }
            }
            when /ADDNODE\s(.+)/ {
                $neighbours{$0};
            }
            when /DELNODE\s(.+)/ {
                $neighbours{$0}:delete;
            }
        }
    }
}

# if file not local ask another
# Node for a link for download
method download($path) {

}

method serve {
    self.announce;
    self.listen;
}
