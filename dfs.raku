#!/usr/bin/env raku

use lib '.';

unit sub MAIN(
    :sa(:$sock-addr) = 'localhost', #= Bind to this address for the udp/tcp server
    :sp(:$sock-port) = 9988,        #= Bind to this port for the udp/tcp server
    :wa(:$web-addr) = 'localhost',  #= Bind to this address for the web server
    :wp(:$web-port) = 8080,         #= Bind to this port for the web server
    :n(:@nodes),                    #= Nodes (ip:port) to sync index/files with
    *@paths,                        #= Path to directories to share
);

use Node;
our $node = Node.new: :lhost($sock-addr), :lport($sock-port), :@paths;
$node.serve;
say $node.index.raku;

use Web;
SITE.serve(:host($web-addr), :port($web-port));
