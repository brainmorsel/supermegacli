#!/usr/bin/env bash

MEGA_EXE="megacli"
MEGA_FLAGS="-NoLog"
MEGA_CTL_ID="0"
MEGA_EXE_VARIANTS=(
  "/opt/MegaRAID/MegaCli/MegaCli"
  "/opt/MegaRAID/MegaCli/MegaCli64"
)
MEGA_ZABBIX_CACHE="/tmp/supermegacli-zabbix.cache"
MEGA_ZABBIX_CACHE_TTL=55  # seconds
OWN_EXE="$0"


help_usage()
{
  cat >&2 <<- EOF
	Usage:
	    ${OWN_EXE} [options] {command}
	
	Options:
	    -e=|--megacli-exe=PATH  Path to MegaCli executable.
	    -a=|--adapter=N         Adapter number or "all" (default 0).
	    -h|--hide-headers       Don't show table headers.

	EOF
	help_commands
}

help_commands()
{
  cat >&2 <<- EOF
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
	EOF
}

help_error()
{
  echo -e "$1\n" >&2
  help_usage
}

main()
{
  if ! mega_detect ;then
      echo -e "Warning: MegaCli executable not found.\n" >&2
  fi

  for opt in "$@"; do
    case "$opt" in
      -e=*|--megacli-exe=*)
        MEGA_EXE="${opt#*=}"
        shift
        ;;
      -a=*|--adapter=*)
        MEGA_CTL_ID="${opt#*=}"
        shift
        ;;
      -h|--hide-headers)
        OPT_HIDE_HEADERS=1
        shift
        ;;
      -d|--dry-run)
        OPT_DRY_RUN=1
        OPT_HIDE_HEADERS=1
        shift
        ;;
      -*)
        help_error "Error: unknown option: $opt"
        ;;
      *)
        # skip arguments
    esac
  done

  if [[ -z "$1" ]] ;then
    interact
    exit
  fi
  
  case "$1" in
    pd)
      shift
      mega_cmd_pd "${@}"
      ;;
    vd)
      shift
      mega_cmd_vd "${@}"
      ;;
    adp)
      shift
      mega_cmd_adp "${@}"
      ;;
    zabbix)
      shift
      mega_cmd_zabbix "${@}"
      ;;
    help)
      if [[ "${OPT_INTERACTIVE}" -eq 1 ]] ;then
        help_commands
      else
        help_usage
      fi
      ;;
    *)
      help_error "Error: unknown command: $1"
  esac
}

interact()
{
  OPT_INTERACTIVE=1

  echo "Welcolme to SuperMegaCli. Type 'help' for list of commands."
  while read -e -a cmds -p "supermegacli:${MEGA_CTL_ID}> "
  do
    if [[ "${cmds[0]}" == "exit" ]] ;then
      break
    fi
    if [[ -n "${cmds[0]}" ]] ;then
      main "${cmds[@]}"
      history -s "${cmds[@]}"
    fi
  done
  echo
}

mega_cmd_pd()
{
  case "$1" in
    list)
      mega_cmd_pd_list
      ;;
    count)
      mega_cmd_pd_count
      ;;
    info)
      shift
      mega_runa -PDInfo -PhysDrv $(mega_physdrv "$@")
      ;;
    missing)
      shift
      mega_cmd_pd_missing "${@}"
      ;;
    hotspare)
      shift
      mega_cmd_pd_hotspare "${@}"
      ;;
    online)
      shift
      mega_runa -PDOnline -PhysDrv $(mega_physdrv "$@")
      ;;
    offline)
      shift
      mega_runa -PDOffline -PhysDrv $(mega_physdrv "$@")
      ;;
    makegood)
      shift
      mega_runa -PDMakeGood -PhysDrv $(mega_physdrv "$@")
      ;;
    makejbod)
      shift
      mega_runa -PDMakeJBOD -PhysDrv $(mega_physdrv "$@")
      ;;
    rebuild)
      shift
      mega_cmd_pd_rebuild "$@"
      ;;
    clear)
      shift
      mega_cmd_pd_clear "$@"
      ;;
    locate)
      shift
      mega_cmd_pd_locate "$@"
      ;;
    remove)
      shift
      mega_cmd_pd_remove "$@"
      ;;
    *)
      help_usage
  esac
}

mega_cmd_pd_missing()
{
  case "$1" in
    show)
      mega_runa -PdGetMissing
      ;;
    mark)
      shift
      mega_runa -PdMarkMissing -PhysDrv $(mega_physdrv "$@")
      ;;
    replace)
      local array="$2"
      local row="$3"
      shift 3
      mega_runa -PdReplaceMissing -PhysDrv $(mega_physdrv "$@") -Array ${array} -Row ${row}
      ;;
    *)
      help_usage
  esac
}

mega_cmd_pd_hotspare()
{
  case "$1" in
    set)
      shift
      mega_runa -PDHSP -Set -PhysDrv $(mega_physdrv "$@")
      ;;
    dedicated)
      local array="$2"
      shift 2
      mega_runa -PDHSP -Set -Dedicated -Array ${array} -PhysDrv $(mega_physdrv "$@")
      ;;
    remove)
      shift
      mega_runa -PDHSP -Rmv -PhysDrv $(mega_physdrv "$@")
      ;;
    *)
      help_usage
  esac
}

mega_cmd_pd_rebuild()
{
  case "$1" in
    show)
      shift
      mega_runa -PDRbld -ShowProg -PhysDrv $(mega_physdrv "$@")
      ;;
    start)
      shift
      mega_runa -PDRbld -Start -PhysDrv $(mega_physdrv "$@")
      ;;
    stop)
      shift
      mega_runa -PDRbld -Stop -PhysDrv $(mega_physdrv "$@")
      ;;
    *)
      help_usage
  esac
}

mega_cmd_pd_clear()
{
  case "$1" in
    show)
      shift
      mega_runa -PDClear -ShowProg -PhysDrv $(mega_physdrv "$@")
      ;;
    start)
      shift
      mega_runa -PDClear -Start -PhysDrv $(mega_physdrv "$@")
      ;;
    stop)
      shift
      mega_runa -PDClear -Stop -PhysDrv $(mega_physdrv "$@")
      ;;
    *)
      help_usage
  esac
}

mega_cmd_pd_locate()
{
  case "$1" in
    start)
      shift
      mega_runa -PdLocate -Start -PhysDrv $(mega_physdrv "$@")
      ;;
    stop)
      shift
      mega_runa -PdLocate -Stop -PhysDrv $(mega_physdrv "$@")
      ;;
    *)
      help_usage
  esac
}

mega_cmd_pd_remove()
{
  case "$1" in
    start)
      shift
      mega_runa -PdPrpRmv -PhysDrv $(mega_physdrv "$@")
      ;;
    stop)
      shift
      mega_runa -PdPrpRmv -UnDo -PhysDrv $(mega_physdrv "$@")
      ;;
    *)
      help_usage
  esac
}

mega_cmd_vd()
{
  case "$1" in
    count)
      mega_cmd_vd_count
      ;;
    list)
      mega_cmd_vd_list
      ;;
    info)
      shift
      mega_runa -LDInfo -L"$1"
      ;;
    *)
      help_usage
   esac
}

mega_cmd_adp()
{
  case "$1" in
    info)
      mega_runa -AdpAllInfo
      ;;
    count)
      mega_cmd_adp_show_count
      ;;
    log)
      mega_runa -AdpAlILog
      ;;
    *)
      help_usage
   esac
}

mega_cmd_zabbix()
{
  case "$1" in
    check)
      shift
      mega_cmd_zabbix_check "$@"
      ;;
    sudoers)
      local script_path=$(readlink -f "${BASH_SOURCE[0]}")
      echo "zabbix ALL=(ALL) NOPASSWD: ${script_path} zabbix check *"
      ;;
    config)
      local script_path=$(readlink -f "${BASH_SOURCE[0]}")
      echo "UserParameter=lsimegaraid[*],sudo ${script_path} zabbix check \$1 \$2"
      ;;
  esac
}

#------------------------------------------------------------------------------
# Utility functions.
#------------------------------------------------------------------------------
mega_detect()
{
    if [[ -x "${MEGA_EXE}" ]] ;then
      return 0
    fi

    if which megacli >/dev/null 2>&1 ;then
      MEGA_EXE=$(which megacli)
      return 0
    fi

    for v in "${MEGA_EXE_VARIANTS[@]}" ;do
      if [[ -x "$v" ]] ;then
        MEGA_EXE="${v}"
        return 0
      fi
    done

    return 1
}

mega_run()
{
  if [[ "$OPT_DRY_RUN" -eq 1 ]] ;then
    echo ${MEGA_EXE} "$@" ${MEGA_FLAGS} 1>&2
  else
    ${MEGA_EXE} "$@" ${MEGA_FLAGS}
  fi
}

mega_runa()
{
  mega_run "$@" -a${MEGA_CTL_ID}
}

mega_physdrv()
{
  local pd_ids="$@"
  echo "[${pd_ids// /,}]"
}


#------------------------------------------------------------------------------
# Command handle functions.
#------------------------------------------------------------------------------
mega_cmd_pd_list()
{
  mega_runa -PDList | awk -v hide_headers=$OPT_HIDE_HEADERS -F: '
  function ltrim(s) { sub(/^[ \t\r\n]+/, "", s); return s }
  function rtrim(s) { sub(/[ \t\r\n]+$/, "", s); return s }
  function trim(s)  { return rtrim(ltrim(s)); }
  function fmt_size(s) { split(s, a, " "); return a[1] a[2] }
  function fmt_temp(s) { split(s, a, " "); return a[1] }
  function fmt_state(s) {
    sub(", ", ":", s)
    sub(" ", "", s)
    return tolower(s)
  }
  BEGIN {
    media_types["Solid State Device"] = "SSD"
    media_types["Hard Disk Device"] = "HDD"

    if (!hide_headers) {
      FMT = "%6s  %4s  %10s  %6s  %5s  %4s  %5s  %3s  %16s\n"
      printf FMT, "ID", "Type", "Size", "FW Ver", "Media", "Temp", "Err", "PFC", "State"
    }
  }
  {
    key = trim($1)
    value = trim($2)
    
    if (d["Enclosure Device ID"] && (key == "Enclosure Device ID" || key == "Exit Code")) {
      dev_id = d["Enclosure Device ID"] ":" d["Slot Number"];
      media = media_types[d["Media Type"]]
      pd_type = d["PD Type"]
      pd_size = fmt_size(d["Raw Size"])
      fw_ver = d["Device Firmware Level"]
      temp = fmt_temp(d["Drive Temperature"])
      err = d["Media Error Count"] "/" d["Other Error Count"]
      pfc = d["Predictive Failure Count"]
      state = fmt_state(d["Firmware state"])

      printf FMT, dev_id, pd_type, pd_size, fw_ver, media, temp, err, pfc, state
      delete d
    }
    d[key] = value
  }
  '
}

mega_cmd_pd_count()
{
  mega_runa -PDGetNum | awk -F': ' '
  /Number of Physical Drives/ { print $2 }
  '
}

mega_cmd_vd_list()
{
  mega_runa -LDInfo -Lall | awk -v hide_headers=$OPT_HIDE_HEADERS -F':' '
  function ltrim(s) { sub(/^[ \t\r\n]+/, "", s); return s }
  function rtrim(s) { sub(/[ \t\r\n]+$/, "", s); return s }
  function trim(s)  { return rtrim(ltrim(s)); }
  function fmt_id(s) { split(s, a, " "); return a[1] }
  function fmt_size(s) { split(s, a, " "); return a[1] a[2] }
  function fmt_level(s) { split(s, a, ", "); s = a[1]; sub(/[^0-9]+/, "", s); return "R" s }
  BEGIN {
    FMT = "%2s  %-10s  %2s  %10s  %-12s  %5s  %-3s  %6s  %2s  %2s  %-3s  %-6s\n"
    if (!hide_headers) {
      printf FMT, "ID", "Name", "Lv", "Size", "State", "Sctr", "Emu", "Strip", "N", "SD", "BB", "Cached"
    }
  }
  {
    key = trim($1)
    value = trim($2)
    
    if (d["Virtual Drive"] && key == "") {
      vd_id = fmt_id(d["Virtual Drive"])
      name = d["Name"]
      level = fmt_level(d["RAID Level"])
      size = fmt_size(d["Size"])
      sector_size = d["Sector Size"]
      is_emulated = d["Is VD emulated"]
      state = d["State"]
      strip_size = fmt_size(d["Strip Size"])
      drives_num = d["Number Of Drives"]
      span_depth = d["Span Depth"]
      if (span_depth > 1)
        drives_num = d["Number Of Drives per span"] * span_depth
      bad_blocks = d["Bad Blocks Exist"]
      cached = d["Is VD Cached"]

      printf FMT, vd_id, name, level, size, state, sector_size, is_emulated, strip_size, drives_num, span_depth, bad_blocks, cached
      delete d
    }
    d[key] = value
  }
  '
}

mega_cmd_vd_count()
{
  mega_runa -LDGetNum | awk -F': ' '
  /Number of Virtual Drives/ { print $2 }
  '
}

mega_cmd_adp_show_count()
{
  mega_run -adpCount | awk '
  /Controller Count/ { sub(/[^0-9]+/, "", $3); print $3 }
  '
}

mega_cmd_zabbix_check()
{
  if [[ -n "$1" && -z "$2" ]] ;then
    mega_cmd_zabbix_discovery "$1"
  elif [[ -n "$1" && -n "$2" ]] ;then
    local drive="$1"
    local metric="$2"

    local cachetime=0
    if [[ -s "${MEGA_ZABBIX_CACHE}" ]] ;then
      cachetime=$(stat -c %Y "${MEGA_ZABBIX_CACHE}")
    fi

    if [[ $(( $(date +%s) - $cachetime )) -gt "${MEGA_ZABBIX_CACHE_TTL}" ]] ;then
      mega_cmd_zabbix_write_cache
    fi

    awk -F':' "/${drive} ${metric}/ { print \$2 }" "${MEGA_ZABBIX_CACHE}"
  else
    exit 1
  fi

}

mega_cmd_zabbix_discovery()
{
  case "$1" in
    virtdiscovery)
      mega_runa -LDInfo -LAll | awk '
        BEGIN {
          sep = " "
          print "{ \"data\":["
        }
        /Virtual Drive:/ { 
          printf "%s{\"{#VIRTNUM}\":\"VirtualDrive%d\"}\n", sep, $3
          sep = ","
        }
        END { print "]}" }
        '
      ;;
    physdiscovery)
      mega_runa -PDList | awk '
        BEGIN {
          sep = " "
          print "{ \"data\":["
        }
        /Slot Number:/ { 
          printf "%s{\"{#PHYSNUM}\":\"DriveSlot%d\"}\n", sep, $3
          sep = ","
        }
        END { print "]}" }
        '
      ;;
  esac
}

mega_cmd_zabbix_write_cache()
{
  mega_runa -PDList | awk -F':' '
    function ltrim(s) { sub(/^[ \t]+/, "", s); return s }
    function rtrim(s) { sub(/[ \t]+$/, "", s); return s }
    function trim(s)  { return rtrim(ltrim(s)); }
    /Slot Number/              {slotcounter+=1; slot[slotcounter]=trim($2)}
    /Inquiry Data/             {inquiry[slotcounter]=trim($2)}
    /Firmware state/           {state[slotcounter]=trim($2)}
    /Drive Temperature/        {temperature[slotcounter]=trim($2)}
    /S.M.A.R.T/                {smart[slotcounter]=trim($2)}
    /Media Error Count/        {mediaerror[slotcounter]=trim($2)}
    /Other Error Count/        {othererror[slotcounter]=trim($2)}
    /Predictive Failure Count/ {failurecount[slotcounter]=trim($2)}
    END {
      for (i=1; i<=slotcounter; i+=1) {
        printf ( "DriveSlot%d inquiry:%s\n",slot[i], inquiry[i]);
        printf ( "DriveSlot%d state:%s\n", slot[i], state[i]);
        printf ( "DriveSlot%d temperature:%d\n", slot[i], temperature[i]);
        printf ( "DriveSlot%d smart:%s\n", slot[i], smart[i]);
        printf ( "DriveSlot%d mediaerror:%d\n", slot[i], mediaerror[i]);
        printf ( "DriveSlot%d othererror:%d\n", slot[i], othererror[i]);
        printf ( "DriveSlot%d failurecount:%d\n", slot[i], failurecount[i]);
      }
    }' > "${MEGA_ZABBIX_CACHE}"

  mega_runa -LDInfo -LAll | awk -F':' '
    function ltrim(s) { sub(/^[ \t]+/, "", s); return s }
    function rtrim(s) { sub(/[ \t]+$/, "", s); return s }
    function trim(s)  { return rtrim(ltrim(s)); }
    /Virtual Drive:/ {drivecounter+=1; slot[drivecounter]=trim($2);}
    /State/          {state[drivecounter]=trim($2)}
    /Bad Blocks/     {badblock[drivecounter]=trim($2)}
    END {
      for (i=1; i<=drivecounter; i+=1) {
        printf ( "VirtualDrive%d state:%s\n", slot[i], state[i]);
        printf ( "VirtualDrive%d badblock:%s\n", slot[i], badblock[i]);
      }
    }' >> "${MEGA_ZABBIX_CACHE}"
}


#------------------------------------------------------------------------------
# Entry point.
#------------------------------------------------------------------------------
main "${@}"
# vim: set ts=2 sw=2 expandtab:
