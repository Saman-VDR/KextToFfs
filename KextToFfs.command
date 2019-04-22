#!/bin/bash
#
# KextToFfs Reloaded - A script to generate ffs files
# 	Based on kext2ffs by FredWsta and STLVNUB
#
# Inspired by:
#	https://www.insanelymac.com/forum/topic/291655-ozmosis/
# 	https://github.com/tuxuser/kext2ffs
# 	https://github.com/cecekpawon/OSXOLVED/blob/master/yod-KextToFfs.sh
# 	https://github.com/cecekpawon/ToFfs
# 
# ———————————————————————————————————————————————————————————————————————————————
#
# Install:
# 	Place KextToFfs into a separate directory.
#	Make the script executable - Terminal: chmod +x ./KextToFfs.command
#	DoubleClick KextToFfs to execute.
#	At the first run, KextToFfs will download the required binary files,
#	and create the subdirectories, where you can place your kext's.
#	If you want all files in one place, create a directory 'Files' beside
#   KextToFfs. Now copy all your files inside this directory.
#
#	Some firmware modules like Ozmosis, require a 'DXE dependency section' for
#	proper execution. You can extract this section from any XMAS firmware.
#	Place it beside the relevant .efi and give it the same name but use .bin 
#	as a file extension.
#
# Filenames and GUID:
#	To generate a ffs with a correct GUID, you have to use a correct filename.
#	KextToFfs detect the correct GUID from the filename in a very strict way.
#	But it's simple, just use the 'original' names like 'ApfsDriverLoader.efi'
#	or 'CPUSensors.kext'. 
#	Unknown kext got a GUID in the DADE10XX-1B31-4FE4-8557-26FCEFC78275 range.
#	Unknown efi modules got a unique GUID generated from the given filename.
#	KextToFfs can generate many .plist at once but it assumes that these are all
#	OzmosisDefault.plist. For this reason they all will got the same GUID
#
#
# Attention:
#	This script is intended to generate correct ffs files.
#	If you get any warnings with UEFITool after saving your new firmware,
#	SOMETHING WENT WRONG and you should NOT USE the firmware in any case! 
#
# ———————————————————————————————————————————————————————————————————————————————
#
# Configuration
#

# Add version string to kext (comment to disable)
#kextVersionString=".Rev-"

# Get GenSec and GenFfs from
binaryUrl=https://raw.githubusercontent.com/tuxuser/kext2ffs/master/bin

#
# ———————————————————————————————————————————————————————————————————————————————
#

appVersion="1.0"
Green="\033[0;32m"
Blue="\033[1;34m"
Normal="\033[0m"
Red="\033[1;31m"

workDir=$(dirname "$0")
binDir="$workDir"/bin
ffsDir="$workDir"/Ffs
srcDir="$workDir"/Files
kextDir="$srcDir"
efiDir="$srcDir"
ozdDir="$srcDir"

# built-in
GenGuid='#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Digest::SHA "sha1";

# Return a GUID from a given string or from uuid.

my $usage = <<"END";
Usage:
    $0 -n FileName
Options:
    -h | -? | --help              This help
    -n | --name FileName          Name to generate the GUID
END

my $name;

GetOptions(
	"h|?|help"	=> sub { print $usage; exit 0 },
	"n|name=s"	=> \$name,
) or die $usage;


sub read_guid
{
	my $data = shift;
	my $offset = shift;

	my ($g1,$g2,$g3,$g4,@g5) = unpack("VvvnCCCCCC", substr($data, $offset, 16));

	return sprintf "%08x-%04x-%04x-%04x-%02x%02x%02x%02x%02x%02x",
		$g1,
		$g2,
		$g3,
		$g4,
		$g5[0],
		$g5[1],
		$g5[2],
		$g5[3],
		$g5[4],
		$g5[5],
		;
}

if ($name)
{
	my $guid = substr(sha1($name), 0, 16);
	$guid = uc read_guid($guid, 0);
	print "$guid\n";
}
else
{
	my $uuid=`uuidgen`;
	chomp $uuid;
	print "$uuid\n";
}
'

kext2ffs() {	
	b=$(basename $1 .kext)
	version=$b

    h=$(printf "%02X" $2)
	guid=DADE10${h}-1B31-4FE4-8557-26FCEFC78275
	t=Info$("$binDir/GenGuid")
	
	if [ x"$kextVersionString" != x ]; then
		cp -p "$kextDir/$1/Contents/Info.plist" "$workDir/$t.plist"
    	name=$(defaults read "$workDir/$t" "CFBundleName" 2>&1 )
    	version=$(defaults read "$workDir/$t" "CFBundleShortVersionString" 2>&1 ) 
    	case $version in
        	*"does not exist")
            	version=$b
        	;;
        	*)
            	version=$b$kextVersionString$version
            	result=$(defaults write "$workDir/$t" "CFBundleName" -string $version 2>&1 )
    			plutil -convert xml1 "$workDir/$t.plist"
        	;;
		esac
	fi
	
	c=${version}Compress

	if 	[ -f "$workDir/$t.plist" ]; then
		cat "$workDir/$t.plist" NullTerminator "$kextDir/$1/Contents/MacOS/$b" > "$b.bin" 2>/dev/null
		rm "$workDir/$t.plist"
	else
		cat "$kextDir/$1/Contents/Info.plist" NullTerminator "$kextDir/$1/Contents/MacOS/$b" > "$b.bin" 2>/dev/null
	fi

    "$binDir"/GenSec -s EFI_SECTION_RAW -o $b.pe32 $b.bin
    "$binDir"/GenSec -s EFI_SECTION_USER_INTERFACE -n $version -o $b-1.pe32
    "$binDir"/GenFfs -t EFI_FV_FILETYPE_FREEFORM -g $guid -o "$ffsDir"/Kext/${guid}_$version.ffs -i $b.pe32 -i $b-1.pe32
	"$binDir"/GenSec -s EFI_SECTION_COMPRESSION -o $b-2.pe32 $b.pe32 $b-1.pe32
    "$binDir"/GenFfs -t EFI_FV_FILETYPE_FREEFORM -g $guid -o "$ffsDir"/Kext/Compress/${guid}_$c.ffs -i $b-2.pe32


	printf "${Blue}|${Green} %-32s ${Blue}|${Green} %-36s ${Blue}|${Green} %-32s ${Blue}|\n" "$1" "$guid" "$version"
}

efi2ffs() {
    b=$(basename $1 .efi)
    c=${b}Compress
    guid=$2
    
    if [ -f "$efiDir"/$b.bin ]; then
		"$binDir"/GenSec -s EFI_SECTION_DXE_DEPEX -o $b-0.pe32 "$efiDir"/$b.bin
	    "$binDir"/GenSec -s EFI_SECTION_PE32 -o $b.pe32 "$efiDir"/$b.efi
    	"$binDir"/GenSec -s EFI_SECTION_USER_INTERFACE -n $b -o $b-1.pe32
    	"$binDir"/GenFfs -t EFI_FV_FILETYPE_DRIVER -g $guid -o "$ffsDir"/Efi/${guid}_$b.ffs -i $b-0.pe32 -i $b.pe32 -i $b-1.pe32
    	"$binDir"/GenSec -s EFI_SECTION_COMPRESSION -o $b-2.pe32 $b.pe32 $b-1.pe32
    	"$binDir"/GenFfs -t EFI_FV_FILETYPE_DRIVER -g $guid -o "$ffsDir"/Efi/Compress/${guid}_$c.ffs -i $b-0.pe32 -i $b-2.pe32
	else
	    "$binDir"/GenSec -s EFI_SECTION_PE32 -o $b.pe32 "$efiDir"/$b.efi
    	"$binDir"/GenSec -s EFI_SECTION_USER_INTERFACE -n $b -o $b-1.pe32
    	"$binDir"/GenFfs -t EFI_FV_FILETYPE_DRIVER -g $guid -o "$ffsDir"/Efi/${guid}_$b.ffs -i $b.pe32 -i $b-1.pe32
    	"$binDir"/GenSec -s EFI_SECTION_COMPRESSION -o $b-2.pe32 $b.pe32 $b-1.pe32
    	"$binDir"/GenFfs -t EFI_FV_FILETYPE_DRIVER -g $guid -o "$ffsDir"/Efi/Compress/${guid}_$c.ffs -i $b-2.pe32
	fi

    printf "${Blue}|${Green} %-32s ${Blue}|${Green} %-36s ${Blue}|${Green} %-32s ${Blue}|\n" "$1" "$guid" "$b"
}

ozd2ffs() {
    b=$(basename $1 .plist)
    c=${b}Compress
	guid=99F2839C-57C3-411E-ABC3-ADE5267D960D

    "$binDir"/GenSec -s EFI_SECTION_RAW -o $b.pe32 "$ozdDir"/$b.plist
    "$binDir"/GenSec -s EFI_SECTION_USER_INTERFACE -n "OzmosisDefaults" -o $b-1.pe32
    "$binDir"/GenFfs -t EFI_FV_FILETYPE_FREEFORM -g $guid -o "$ffsDir"/Ozd/${guid}_$b.ffs -i $b.pe32 -i $b-1.pe32
    "$binDir"/GenSec -s EFI_SECTION_COMPRESSION -o $b-2.pe32 $b.pe32 $b-1.pe32
    "$binDir"/GenFfs -t EFI_FV_FILETYPE_FREEFORM -g $guid -o "$ffsDir"/Ozd/Compress/${guid}_$c.ffs -i $b-2.pe32

    printf "${Blue}|${Green} %-32s ${Blue}|${Green} %-36s ${Blue}|${Green} %-32s ${Blue}|\n" "$1" "$guid" "$b"
}


generateKext() {
    [ -d "$ffsDir"/Kext ] && rm -rf "$ffsDir"/Kext
    mkdir "$ffsDir"/Kext
    mkdir "$ffsDir"/Kext/Compress
    x=11
    for a in $(ls "$kextDir" | grep ".kext$"); do
        case "$a" in
            "SmcEmulator.kext" | "FakeSMC.kext")
            	kext2ffs $a 1
            	;;
         
        	"Disabler.kext")
            	kext2ffs $a 2
            	;;
         
        	"Injector.kext")
            	kext2ffs $a 3
            	;;
            	
        	"RealtekRTL8111.kext")
            	kext2ffs $a 4
            	;;
            	
        	"ACPISensors.kext" | "FakeSMC_ACPISensors.kext")
            	kext2ffs $a 5
            	;;
            	
        	"CPUSensors.kext" | "FakeSMC_CPUSensors.kext")
            	kext2ffs $a 6
            	;;
            	          
        	"LPCSensors.kext" | "FakeSMC_LPCSensors.kext")
            	kext2ffs $a 7
            	;;
            	
        	"GPUSensors.kext" | "FakeSMC_GPUSensors.kext")
            	kext2ffs $a 8
            	;;
            	
        	"VoodooHdaKext.kext")
            	kext2ffs $a 9
            	;;
            	
        	"Lilu.kext")
            	kext2ffs $a 10
            	;;

        	*)
        		if [[ $x -gt 255 ]]; then
        			printf "${Blue}|${Green} %-32s ${Blue}|${Red} %-36s ${Blue}|${Green} %-32s ${Blue}|\n" "$a" "kext(s) limit exceeded" ""
        		else
	            	kext2ffs $a $x
    	        	let x++
    	        fi
            	;; 
        esac
    done
}

generateEfi(){
    [ -d "$ffsDir"/Efi ] && rm -rf "$ffsDir"/Efi
    mkdir "$ffsDir"/Efi
    mkdir "$ffsDir"/Efi/Compress

    for a in $(ls "$efiDir" | grep ".efi$"); do

		guid=$("$binDir/GenGuid")
		
    	case "$a" in
	        "AcpiPatcher.efi")
    	        guid=AB6CE992-8D17-4C3A-A414-0FEAA3904504
        	;;
	        "ApfsDriverLoader.efi")
    	        guid=18F0F325-E54C-2994-E37E-E6949EC94D45
        	;;
	        "DarBoot.efi")
    	        guid=D796347F-48B9-4576-BF08-B98899A4BA45
        	;;
	        "DBounce.efi")
    	        guid=F97ABEC7-BC15-4954-B4A7-83FC6323D27C
        	;;
	        "DevProp.efi")
    	        guid=FEA827B8-C87A-4EEA-B7AB-DF586AF23637
        	;;
	        "EfiDevicePathPropertyDatabase.efi")
    	        guid=35628CFC-3CFF-444F-99C1-D5F06A069914
        	;;
        	"EnhancedFat.efi" | "Fat.efi")
	            guid=961578FE-B6B7-44C3-AF35-6BC705CD2B1F
    	    ;;
        	"ExtFs.efi")
            	guid=B34E5765-2E04-4DAF-867F-7F40BE6FC33D
        	;;
        	"HermitShellX64.efi")
            	guid=C57AD6B7-0515-40A8-9D21-551652854E37
        	;;
        	"KernextPatcher.efi")
            	guid=99665243-5AED-4D57-92AF-8C785FBC7558
        	;;
        	"Ozmosis.efi")
            	guid=AAE65279-0761-41D1-BA13-4A3C1383603F
        	;;
        	"OsxAptioFix2Drv.efi" | "AptioFix2")
            	guid=ED5C3A97-D211-6FBA-B9F1-0780047A6F7B
        	;;
        	*)
            	guid=$("$binDir/GenGuid" -n $(basename $a .efi))
        	;;
		esac
		
        efi2ffs $a $guid
        
    done
}

generateOzd() {
    [ -d "$ffsDir"/Ozd ] && rm -rf "$ffsDir"/Ozd
    mkdir "$ffsDir"/Ozd
    mkdir "$ffsDir"/Ozd/Compress

    for a in $(ls "$ozdDir" | grep ".plist$"); do
        ozd2ffs $a
    done
}

printLine() {
	printf "${Blue}——————————————————————————————————————————————————————————————————————————————————————————————————————————————\n"
}

printField() {
	printf "${Blue}|${Green} %-106s ${Blue}|\n" "$1"
}

main() {
	printf '\033[8;40;110t'
	cd "$workDir"

	printLine
	printField
	printField "KextToFfs Reloaded $appVersion"
	printField "Convert Efi, Kext and OzmosisDefaults.plist to FFS type file"
	printf "${Blue}|${Green} Output directory: ${Red}%-88s ${Blue}|\n" "$ffsDir"
	printField
	
	# Create directorys
	if [ ! -d "$srcDir" ]; then
		kextDir="$workDir"/Kext
		[ -d "$kextDir" ] || mkdir -p "$kextDir"

		efiDir="$workDir"/Efi
		[ -d "$efiDir" ] || mkdir -p "$efiDir"

		ozdDir="$workDir"/Ozd
		[ -d "$ozdDir" ] || mkdir -p "$ozdDir"
	fi

	# Install binary tools
	[ -d "$binDir" ] || mkdir -p "$binDir"
	a=("GenSec" "GenFfs")
	for x in "${a[@]}"; do
		if [ ! -f "$binDir/$x" ]; then
			printf "${Blue}|${Green} %-106s ${Blue}|\n" "Installing $x ..."
			curl -so "$binDir/$x" $binaryUrl/$x && chmod +x "$binDir/$x"
		fi
  	done
  	# Create GenGuid
	if [ ! -x "$binDir/GenGuid" ]; then
		printf "${Blue}|${Green} %-106s ${Blue}|\n" "Installing GenGuid ..."
		echo "$GenGuid" > "$binDir/GenGuid" && chmod +x "$binDir/GenGuid"
		printField
	fi

	printLine
	printf "${Blue}|${Green} %-32s ${Blue}|${Green} %-36s ${Blue}|${Green} %-32s ${Blue}|\n" "File" "GUID" "Name"
	printLine

	[ -d "$ffsDir" ] || mkdir -p "$ffsDir"
	dd if=/dev/zero of=NullTerminator bs=1 count=1 1>/dev/null 2>&1

	case $1 in
    	*Kext)
        	generateKext
    	;;
   		*Efi)
        	generateEfi
    	;;
    	*Ozd)
        	generateOzd
    	;;

    	*)
        	generateKext
        	generateEfi
        	generateOzd
    	;;
	esac

	printLine
	echo -e $Normal

	# clean up
	rm NullTerminator 1>/dev/null 2>&1
	rm *.pe32 1>/dev/null 2>&1
	rm *.bin 1>/dev/null 2>&1
	exit
}

main
