use Air::Functional :BASE;
use Air::Base;
use Air::Component;

class File does Component {
    has $.filename;

    method download is controller {
        say "Downloading $.filename !";
        "Download"
    }
}

class FileList does Component {
    method refresh is controller {
        self.HTML
    }

    method hx-refresh(--> Hash()) {
        :hx-get("$.url-path/refresh"),
        :hx-target("tbody"),
        :hx-swap<innerHTML>,
    }

    method HTML {
        ~ do for $*node.index.keys.sort -> $filename {
            my $file = File.new(:$filename);
            tr
                td( $file.filename ~ "({$file.id})"),
                td( button :type<submit>, :hx-get("{$file.url-path}/download"), 'Download')
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

my $filelist = FileList.new;
my $file     = File.new(:filename("to create route"));

sub SITE is export {
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
