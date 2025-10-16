use Air::Functional :BASE;
use Air::Base;
use Air::Component;
use File::Find;

class File does Component {
    has $.filename;

    # TODO implement this
    method download is controller {
        say "Downloading $.filename !";
        "Download"
    }
}

class FileList does Component {
    has $path;

    method refresh is controller {
        self.HTML
    }

    method hx-refresh(--> Hash()) {
        :hx-get("$.url-path/refresh"),
        :hx-target("tbody"),
        :hx-swap<innerHTML>,
    }

    method HTML {
        ~ do for (find(:dir($path), :type('file')) [Z] ^Inf) -> ($filename, $id) {
            my $file = File.new(:$filename, :$.node, :id(+$id));
            tr
                td( $file.filename ),
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

sub SITE($path) is export {
    my $filelist = FileList.new(:$path);
    my $file     = File.new(:filename("to create route"));

    site :register[$filelist, $file],
    index
    main [
        div :style<width:25%; display:flex;>, [
            h3 'Files:';
            button :style<transform:scale(0.80)>, :type<submit>, |$filelist.hx-refresh, 'Refresh';
        ];
        table
            :thead[["filename"]],
            :tbody[[$filelist]];
        form [ input :type<file>; button :type<submit>, 'Upload' ];
    ]
}
