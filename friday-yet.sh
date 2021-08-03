date "+%A" |grep -q "Fri" && ( cowsay -f tux "$(date "+%A") YES"|lolcat -p 1 -F .01 -a ) || cowsay $(date "+%D %A")
