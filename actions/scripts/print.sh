#!/usr/bin/env bash

#Collects all printable Files from directory or selection in a list for printing. Printable files will be auto selected.
#Progress bar will pulsate as long as the collection runs.

#This script needs the following tools: zenity, lp, bc
declare FILES=()
declare PIDFILE=$(mktemp)
declare DEFAULT_PRINTER=$(lpstat -d | cut -d ':' -f2 | xargs)

preflight() {
    local req_pkgs=()
    for p in bc lp zenity; do
        hash $p 2>/dev/null || req_pkgs+=($p)
    done
    if (( ${#req_pkgs[@]} > 0 )); then
        printf -v req_pkgs '%s, ' "${req_pkgs[@]}"
        notify-send -i /usr/share/icons/gnome/48x48/status/dialog-warning.png --expire-time=200000 "[Nemo,Print] Missing req.ackages." "Please install equired packages: ${req_pkgs%,*}"
        exit 1
    fi
}

h=0
collect() {
    local i
    for i in "$@"; do
        if [[ -d $i ]]; then
            collect "$i"/*
        else
            FILES+=("$i")
            h=$((h+1))
        fi
    done
}

slct_prntr() {
    local printers=($(lpstat -p | grep enabled | awk '{print $2}'))
    local list f
    for f in "${printers[@]}"; do
        [[ $DEFAULT_PRINTER == ${f// } ]] && list="$list TRUE $f" || list="$list FALSE $f"
    done
    local selection=$(zenity --hide-header --width 800 --height 600 --list --column Selection --column Printer $list --radiolist --title "Available Printers")
    [[ -n ${selection// } ]] && DEFAULT_PRINTER="$selection" || exit 0
}

prnt() {
    _snd() {
        local i x
        IFS="|" read -ra x

        local m=${#x[@]} g=0
        ( for i in "${x[@]}"; do
            lp -d "$DEFAULT_PRINTER" "$i"
            g=$((g+1))
            bc <<< "scale=2; $g/$m*100"
            sleep 0.2
        done ) | zenity --title "Print Progress" --progress --auto-kill --auto-close
    }

    local list f
    for f in "${FILES[@]}"; do
        file -i "$f" | grep -qE 'image/|text/|application/(pdf|openxmlformats-officedocument)' && list="$list TRUE \"$f\"" || list="$list FALSE \"$f\""
    done

    rm $PIDFILE
    eval zenity --hide-header --width 800 --height 600 --list --column Selection --column File "$list" --checklist | _snd 
}

main() {
    preflight
    local x
    slct_prntr
    IFS=";" read -ra x <<< $*
    touch /tmp/x
    (while true; do [[ -e $PIDFILE ]] && sleep 1 || exit 0; done) | zenity --title "Searching files" --progress --pulsate --auto-kill --auto-close &
    collect "${x[@]}" 
    prnt "${FILES[@]}"
}


main "$@"
