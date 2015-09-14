SuperMegaCli
===

Small sanity saving wrapper around LSI MegaCli.


    Usage:
        ./supermegacli.sh [options] {command}

    Options:
        -e=|--megacli-exe=PATH  Path to MegaCli executable.
        -a=|--adapter=N         Adapter number or "all" (default 0).

    Commands:
        pd show {list | DISK_ID...}  Physical drive info.
        pd set hotspare DISK_ID...
        pd set hotspare dedicated ARRAY DISK_ID...
        vd show {list | DISK_ID...}  Virtual drive info.
        adp show                     Show adapter info.
        adp count                    Show adapters count.
        adp log                      Show adapter internal log.


