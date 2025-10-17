use Air::Functional :BASE;
use Air::Base;
use Air::Component;
use File::Find;

class FileList does Component {
    has $.path;

    method refresh is controller {
        self.HTML
    }

    method hx-refresh(--> Hash()) {
        :hx-get("$.url-path/refresh"),
        :hx-target("tbody"),
        :hx-trigger("every 5s"),
        :hx-swap<innerHTML>,
    }

    method HTML {
        ~ do for find(:dir($!path), :type('file')) -> $filename {
            my $filepath = $filename.relative($!path.IO.parent);
            tr
                td( $filepath ),
                td( a :href($filepath), 'Download')
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

    site :register[$filelist],
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
