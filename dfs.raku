#!/usr/bin/env raku

use lib $*PROGRAM.dirname;
use Node;
use Web;
use Log::Async <debug color>;

subset port of UInt;
subset addr of Str;
unit sub MAIN(
    $path where *.IO.d,                        #= Path to directory to share
    addr :sa(:$sock-addr) = '127.0.0.1', #= Bind to this address for the udp/tcp server
    port :sp(:$sock-port) = 9988,        #= Bind to this port for the udp/tcp server
    addr :wa(:$web-addr)?,  #= Bind to this address for the web server
    port :wp(:$web-port)?,         #= Bind to this port for the web server
    :n(:@nodes)?,                    #= Nodes (ip:port) to sync index/files with
);

my $node = Node.new(
    :lhost($sock-addr),
    :lport($sock-port),
    :nodes((@nodes [X] Nil).flat),
    :$path,
);
$node.serve;

if $web-addr and $web-port {
    SITE($path).serve(:host($web-addr), :port($web-port));
} else {
    react whenever signal(SIGINT) { say "\rBye !"; exit }
}
