#!/bin/bash

Url=https://raw.githubusercontent.com/linuxboot/linuxboot/master
Loop=0

Green="\033[0;32m"
Blue="\033[1;34m"
Normal="\033[0m"
Red="\033[1;31m"

printLine() {
	printf "${Blue}——————————————————————————————————————————————————————————————————————————————————————————————————————————————\n"
}

printField() {
	printf "${Blue}|${Green} %-106s ${Blue}|\n" "$1"
}

main() {
	printf '\033[8;40;110t'
	
	dir="`dirname "$0"`"
	cd "$dir"
	
	printLine
	printField
	printField "FfsToFv 0.1"
	printField "credits for EFI.pm and create-fv to https://github.com/linuxboot/linuxboot"
	printField
	printField "Output to: $dir/firmware(-compress).fv"
	printField

	
	# Install tools
	[ -d "./bin" ] || mkdir -p "./bin"
	[ -d "./lib" ] || mkdir -p "./lib"
	
	if [ ! -x "./bin/create-fv" ]; then
		printField "Installing create-fv ..."
		curl -so "./bin/create-fv" $Url/bin/create-fv && chmod +x "./bin/create-fv"
	fi
	
	if [ ! -f "./lib/EFI.pm" ]; then
		printField "Installing EFI.pm ..."
		curl -so "./lib/EFI.pm" $Url/lib/EFI.pm
	fi
	printField
	printLine
	
	./bin/create-fv -o firmware-compress.fv -s 2097152 ./Ffs/*/Compress/*.ffs
	[ -f ./firmware-compress.fv ] && [ -x ./bin/UEFITool ] && ./bin/UEFITool ./firmware-compress.fv &
	
	./bin/create-fv -o firmware.fv -s 2097152 ./Ffs/*/*.ffs
	[ -f ./firmware.fv ] && [ -x ./bin/UEFITool ] && ./bin/UEFITool ./firmware.fv &
	
	echo -e $Normal
	exit
}

main
