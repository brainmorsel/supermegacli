#!/usr/bin/env bash

MEGA_EXE="megacli"
MEGA_FLAGS="-NoLog"
MEGA_CTL_ID="0"
MEGA_EXE_VARIANTS=(
  "/opt/MegaRAID/MegaCli/MegaCli"
  "/opt/MegaRAID/MegaCli/MegaCli64"
)
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
        exit 1
        ;;
      *)
        # skip arguments
    esac
  done
  
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
    help)
      help_usage
      ;;
    *)
      help_error "Error: unknown command: $1"
      exit 1
  esac
}


#------------------------------------------------------------------------------
# Command line parsing functions.
#------------------------------------------------------------------------------
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
      mega_cmd_pd_info "${@}"
      ;;
    missing)
      shift
      mega_cmd_pd_missing "${@}"
      ;;
    hotspare)
      shift
      mega_cmd_pd_hotspare "${@}"
      ;;
    *)
      help_usage
      exit 1
  esac
}


mega_cmd_pd_missing()
{
  case "$1" in
    show)
      mega_cmd_pd_missing_show
      ;;
    mark)
      shift
      mega_cmd_pd_missing_mark "${@}"
      ;;
    replace)
      shift
      mega_cmd_pd_missing_replace "${@}"
      ;;
    *)
      help_usage
      exit 1
  esac
}


mega_cmd_pd_hotspare()
{
  case "$1" in
    set)
      shift
      mega_cmd_pd_hotspare_set "${@}"
      ;;
    dedicated)
      shift
      mega_cmd_pd_hotspare_dedicated "${@}"
      ;;
    remove)
      shift
      mega_cmd_pd_hotspare_remove "${@}"
      ;;
    *)
      help_usage
      exit 1
  esac
}


mega_cmd_vd()
{
  case "$1" in
    show)
      if [[ -z "$2" || "$2" == "list" ]] ;then
        mega_cmd_vd_show_info all
      else
        mega_cmd_vd_show_info "$2"
      fi
      ;;
    *)
      help_usage
      exit 1
   esac
}


mega_cmd_adp()
{
  case "$1" in
    info)
      mega_cmd_adp_show_info
      ;;
    count)
      mega_cmd_adp_show_count
      ;;
    log)
      mega_cmd_adp_show_log
      ;;
    *)
      help_usage
      exit 1
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

    for viriant in "${MEGA_EXE_VARIANTS}" ;do
      if [[ -x "$variant" ]] ;then
        MEGA_EXE="${variant}"
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
    ${MEGA_EXE} "$@"
  fi
}


#------------------------------------------------------------------------------
# Command handle functions.
#------------------------------------------------------------------------------
mega_cmd_pd_list()
{
  mega_run -PDList -a${MEGA_CTL_ID} | awk -v hide_headers=$OPT_HIDE_HEADERS -F: '
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
      print("ID\tType\tSize\t\tFW Ver\tMedia\tTemp\tErr\tPFC\tState")
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

      print( dev_id "\t" pd_type "\t" pd_size "\t" fw_ver "\t" media "\t" temp "\t" err "\t" pfc "\t" state)
      delete d
    }
    d[key] = value
  }
  END {

  }
  '
}


mega_cmd_pd_info()
{
  local pd_ids="$@"
  mega_run -PDInfo -PhysDrv "[${pd_ids// /,}]" -a${MEGA_CTL_ID}
}


mega_cmd_pd_count()
{
  mega_run -PDGetNum -a${MEGA_CTL_ID} | awk -F': ' '
  /Number of Physical Drives/ { print $2 }
  '
}


mega_cmd_pd_missing_show()
{
  mega_run -PdGetMissing -a${MEGA_CTL_ID}
}


mega_cmd_pd_missing_mark()
{
  local pd_ids="$@"
  mega_run -PdMarkMissing -PhysDrv "[${pd_ids// /,}]" -a${MEGA_CTL_ID}
}


mega_cmd_pd_missing_replace()
{
  local array="$1"
  local row="$2"
  shift 2
  local pd_ids="$@"
  mega_run -PdReplaceMissing -PhysDrv "[${pd_ids// /,}]" -Array $array -Row $row -a${MEGA_CTL_ID}
}


mega_cmd_pd_hotspare_set()
{
  local pd_ids="$@"
  mega_run -PDHSP -Set -PhysDrv "[${pd_ids// /,}]" -a${MEGA_CTL_ID}
}


mega_cmd_pd_hotspare_dedicated()
{
    local array_id="$2"
    shift
    local pd_ids="$@"
    mega_run -PDHSP -Set -Dedicated -Array${array_id} -PhysDrv "[${pd_ids// /,}]" -a${MEGA_CTL_ID}
}


mega_cmd_pd_hotspare_remove()
{
  local pd_ids="$@"
  mega_run -PDHSP -Rmv -PhysDrv "[${pd_ids// /,}]" -a${MEGA_CTL_ID}
}


mega_cmd_vd_show_info()
{
  mega_run -LDInfo -L"$1" -a${MEGA_CTL_ID}
}


mega_cmd_adp_show_info()
{
  mega_run -AdpAllInfo -a${MEGA_CTL_ID}
}


mega_cmd_adp_show_count()
{
  mega_run -adpCount | awk '
  /Controller Count/ { sub(/[^0-9]+/, "", $3); print $3 }
  '
}


mega_cmd_adp_show_log()
{
  mega_run -AdpAlILog -a${MEGA_CTL_ID}
}


#------------------------------------------------------------------------------
# Entry point.
#------------------------------------------------------------------------------
main "${@}"
# vim: set ts=2 sw=2 expandtab:
