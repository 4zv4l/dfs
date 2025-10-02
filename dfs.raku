#!/usr/bin/env raku

use lib '.';
use Node;
use Web;

sub USAGE {
    print q:to/USAGE/;
    Usage:
    ./dfs.raku [options] [<paths> ...]

    Options:
      --sa|--sock-addr=<Str>     Bind to this address for the udp/tcp server [default: 'localhost']
      --sp|--sock-port[=UInt]    Bind to this port for the udp/tcp server [default: 9988]
      --wa|--web-addr=<Str>      Bind to this address for the web server [default: 'localhost']
      --wp|--web-port[=UInt]     Bind to this port for the web server [default: 8080]
      -n|--nodes=<Str> ...       Nodes (ip:port) to sync index/files with
      [<paths> ...]              Path to directories to share
    USAGE
}

unit sub MAIN(
    Str :sa(:$sock-addr) = 'localhost', #= Bind to this address for the udp/tcp server
    UInt :sp(:$sock-port) = 9988,        #= Bind to this port for the udp/tcp server
    Str :wa(:$web-addr) = 'localhost',  #= Bind to this address for the web server
    UInt :wp(:$web-port) = 8080,         #= Bind to this port for the web server
    Str :n(:@nodes),                    #= Nodes (ip:port) to sync index/files with
    *@paths,                        #= Path to directories to share
);

my $node = Node.new: :lhost($sock-addr), :lport($sock-port), :@paths;
$node.serve;

SITE($node).serve(:host($web-addr), :port($web-port));
