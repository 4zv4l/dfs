#!/usr/bin/env raku

use lib $*PROGRAM.dirname;
use Node;
use Web;
use Log::Async <debug color>;

sub USAGE {
    print q:c:to/USAGE/;
    Usage:
      {$*PROGRAM} [options] <path>

      <path>                       Path to the directory to share
      --sa|--sock-addr=<addr>      Bind to this address for the tcp server [default: 127.0.0.1]
      --sp|--sock-port[=port]      Bind to this port for the tcp server [default: 9988]
      --wa|--web-addr=<addr>       Bind to this address for the web server [default: 127.0.0.1]
      --wp|--web-port[=port]       Bind to this port for the web server
      --na|--nodes=<ip:port> ...   Nodes addresses to sync index/files with
    USAGE
}

unit sub MAIN(
    $path where *.IO.d,                  #= Path to directory to share
    Str :sa(:$sock-addr) = '127.0.0.1',  #= Bind to this address for the tcp server
    UInt :sp(:$sock-port) = 9988,        #= Bind to this port for the tcp server
    Str :wa(:$web-addr)  = '127.0.0.1',  #= Bind to this address for the web server
    UInt :wp(:$web-port)?,               #= Bind to this port for the web server
    :na(:@nodes)?,                       #= Nodes (ip:port) to sync index/files with
);

Node.new(
    :lhost($sock-addr),
    :lport($sock-port),
    :nodes((@nodes [X] Nil).flat),
    :$path,
).serve;

if $web-addr and $web-port {
    SITE($path).serve(:host($web-addr), :port($web-port));
} else {
    react whenever signal(SIGINT) { print "\r"; info "Bye !"; exit }
}
