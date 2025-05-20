#!/bin/bash

function Usage() {
  echo "make.sh [ sim | gui | clean ]"
  echo
  echo "   sim      (Default) Builds and simulates the project.pro file"
  echo "   gui      Opens the ModelSim GUI and loads the OSVVM libs"
  echo "   clean    Removes are temporary / compiled files and reports"
  echo
  exit
}

source ../settings.make

if [[ "$1" == "sim" ]] || [[ "$#" == "0" ]]; then
  echo "Starting Simulation..."
  "$MODELSIM_PATH" -batch -logfile "logs/transcript" -do "source ../common.tcl; build project.pro; exit"
  
elif [[ "$1" == "gui" ]]; then
  echo "Starting ModelSim GUI..."
  "$MODELSIM_PATH" -do "source ../common.tcl"

elif [[ "$1" == "clean" ]]; then
  rm -rf VHDL_LIBS
  rm -rf logs
  rm -rf results
  rm -f *.yml
  rm -f *.html
  rm -f transcript
  rm -f *.vstf
  rm -f *.wlf
  rm -f *.vstf
  rm -f modelsim.ini

else
  Usage

fi
