use Air::Functional :BASE;
use Air::Base;
use Air::Component;

class File does Component {
    has $.filename;
    has $.node;

    # TODO implement this
    # use $.node to get the file if the file isnt in the node
    # then it will get a link from another node for the download
    method download is controller {
        say "Downloading $.filename ({$.node.index.raku}) !";
        "Download"
    }
}

class FileList does Component {
    has $.node is rw;

    method refresh is controller {
        self.HTML
    }

    method hx-refresh(--> Hash()) {
        :hx-get("$.url-path/refresh"),
        :hx-target("tbody"),
        :hx-swap<innerHTML>,
    }

    method HTML {
        ~ do for ($.node.index.keys.sort [Z] ^Inf) -> ($filename, $id) {
            my $file = File.new(:$filename, :$.node, :id(+$id));
            tr
                td( $file.filename ~ "({$file.id})"),
                td( a :href("{$file.url-path}/download"), 'Download')
        }
    }
}

my &index = &page.assuming(
    title => 'Test DFS',
    description => 'HTMX, Air, Red, Cro',
    nav => nav(
        logo    => span( ),
        widgets => [lightdark],
    ),
);

sub SITE($node) is export {
    my $filelist = FileList.new(:$node);
    my $file     = File.new(:filename("to create route"));

    site :register[$filelist, $file],
    index
    main [
        h3 'Files:';
        table
            :thead[["filename"]],
            :tbody[[$filelist]];
        button :type<submit>, |$filelist.hx-refresh, 'Refresh';
    ]
}
