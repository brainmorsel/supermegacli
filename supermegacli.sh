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

	Commands:
	    pd show {list | DISK_ID...}  Physical drive info.
	    pd set hotspare DISK_ID...
	    pd set hotspare dedicated ARRAY DISK_ID...
	    vd show {list | DISK_ID...}  Virtual drive info.
	    adp show                     Show adapter info.
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
    show)
      if [[ -z "$2" || "$2" == "list" ]] ;then
        mega_cmd_pd_show_list
      else
        shift
        mega_cmd_pd_show_info "${@}"
      fi
      ;;
    set)
      shift
      mega_cmd_pd_set "${@}"
      ;;
    rem|remove)
      shift
      mega_cmd_pd_remove "${@}"
      ;;
    *)
      help_usage
      exit 1
  esac
}


mega_cmd_pd_set()
{
  case "$1" in
    hotspare)
      shift
      mega_cmd_pd_set_hotspare "${@}"
      ;;
    *)
      help_usage
      exit 1
   esac
}


mega_cmd_pd_set()
{
  case "$1" in
    hotspare)
      shift
      mega_cmd_pd_set_hotspare "${@}"
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
    show)
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


#------------------------------------------------------------------------------
# Command handle functions.
#------------------------------------------------------------------------------
mega_cmd_pd_show_list()
{
  ${MEGA_EXE} -PDList -a${MEGA_CTL_ID} ${MEGA_FLAGS} | awk -F: '
  function ltrim(s) { sub(/^[ \t\r\n]+/, "", s); return s }
  function rtrim(s) { sub(/[ \t\r\n]+$/, "", s); return s }
  function trim(s)  { return rtrim(ltrim(s)); }
  function fmt_size(s) { split(s, a, " "); return a[1] a[2] }
  function fmt_temp(s) { split(s, a, " "); return a[1] }
  BEGIN {
    media_types["Solid State Device"] = "SSD"
    media_types["Hard Disk Device"] = "HDD"

    print("ID\tType\tSize\t\tFW Ver\tMedia\tTemp\tErr\tPFC\tState")
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
      state = d["Firmware state"]

      print( dev_id "\t" pd_type "\t" pd_size "\t" fw_ver "\t" media "\t" temp "\t" err "\t" pfc "\t" state)
      delete d
    }
    d[key] = value
  }
  END {

  }
  '
}


mega_cmd_pd_show_info()
{
  local pd_ids="$@"
  ${MEGA_EXE} -PDInfo -PhysDrv "[${pd_ids// /,}]" -a${MEGA_CTL_ID} ${MEGA_FLAGS}
}


mega_cmd_pd_set_hotspare()
{
  if [[ "$1" == "dedicated" ]] ;then
    local array_id="$2"
    shift 2
    local pd_ids="$@"
    ${MEGA_EXE} -PDHSP -Set -Dedicated -Array${array_id} -PhysDrv "[${pd_ids// /,}]" -a${MEGA_CTL_ID} ${MEGA_FLAGS}
  else
    local pd_ids="$@"
    ${MEGA_EXE} -PDHSP -Set -PhysDrv "[${pd_ids// /,}]" -a${MEGA_CTL_ID} ${MEGA_FLAGS}
  fi
}


mega_cmd_vd_show_info()
{
  ${MEGA_EXE} -LDInfo -L"$1" -a${MEGA_CTL_ID} ${MEGA_FLAGS}
}


mega_cmd_adp_show_info()
{
  ${MEGA_EXE} -AdpAllInfo -a${MEGA_CTL_ID} ${MEGA_FLAGS}
}


mega_cmd_adp_show_count()
{
  ${MEGA_EXE} -adpCount ${MEGA_FLAGS} | awk '
  /Controller Count/ { sub(/[^0-9]+/, "", $3); print $3 }
  '
}


mega_cmd_adp_show_log()
{
  ${MEGA_EXE} -AdpAlILog -a${MEGA_CTL_ID} ${MEGA_FLAGS}
}


#------------------------------------------------------------------------------
# Entry point.
#------------------------------------------------------------------------------
main "${@}"
# vim: set ts=2 sw=2 expandtab:
