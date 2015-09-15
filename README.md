SuperMegaCli
===

Small sanity saving wrapper around LSI MegaCli.

    Usage:
        ./supermegacli.sh [options] {command}

    Options:
        -e=|--megacli-exe=PATH  Path to MegaCli executable.
        -a=|--adapter=N         Adapter number or "all" (default 0).
        -h|--hide-headers       Don't show table headers.

    Commands:
        help
        pd list
        pd count
        pd info DISK_ID...           Physical drive info.
        pd missing show
        pd missing mark DISK_ID...
        pd missing replace ARRAY ROW DISK_ID...
        pd hotspare set DISK_ID...
        pd hotspare dedicated ARRAY DISK_ID...
        pd hotspare remove DISK_ID...
        vd show {list | DISK_ID...}  Virtual drive info.
        adp info                     Show adapter info.
        adp count                    Show adapters count.
        adp log                      Show adapter internal log.


