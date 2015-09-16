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
        pd count
        pd list
        pd info PD_LIST              Physical drive info.
        pd missing show
        pd missing mark PD_LIST
        pd missing replace ARRAY ROW PD_LIST
        pd hotspare set PD_LIST
        pd hotspare dedicated ARRAY PD_LIST
        pd hotspare remove PD_LIST
        pd online PD_LIST
        pd offline PD_LIST
        pd makegood PD_LIST
        pd rebuild {show|start|stop} PD_LIST
        pd clear {show|start|stop} PD_LIST
        pd locate {start|stop} PD_LIST
        pd remove {start|stop} PD_LIST
                                      Prepare drive to remove.
        vd list
        vd info VD                    Virtual drive info.
        adp count                     Show adapters count.
        adp info                      Show adapter info.
        adp log                       Show adapter internal log.

        zabbix check {ZBX_DRIVE ZBX_KEY|ZBX_DISCO_RULE}
                                      Interface for zabbix-agentd.
        zabbix sudoers                Generate sudoers config.
        zabbix config                 Generate zabbix-agentd config.

    Legend:
        PD_LIST   Comma (or space) separated list of PDs.
        PD        Colon separated pair of enclosure id and slot number.

