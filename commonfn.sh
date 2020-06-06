#! /bin/bash

if [ -z $SCRIPTPATH ]; then
   SCRIPT=$0
   pushd $(dirname $0) > /dev/null
   export SCRIPTPATH=$(pwd)
   popd > /dev/null
fi

if [ -z "$_debug" ]; then
   _debug=false
fi
$_debug && echo debug
# Display a debug message depending on the value of _debug
function debug {
   $_debug && echo -e "[DEBUG] $@" 1>&2
   true
}

# Verifies the status flag and then displays the message based on a pass
# or fail. The messages are shown as postit notes. On a fail, the error
# also shown to the command line and the script will be terminated.
function checkStatus {
   OPTIND=0
   local _withpopup=true
   while getopts "q" OPTS
   do
      case $OPTS in 
         q) _withpopup=false
         ;;
         ?) showError "Bad option when using checkStatus"
         ;;
      esac
   done
   shift $(( $OPTIND - 1))
   local status=$1
   shift
   local pass=$1
   shift
   local fail=$1
   shift
   local popup=$1
   shift
   if  [ $status -eq 0 ]; then
      debug "checkStatus - PASS"
      if [ "$pass" != "NOMESSAGE" ]; then
         $_withpopup && $SCRIPTPATH/postit "$pass" 
         echo "$pass"
      fi
   else
      debug "$fail"
      $_withpopup && $SCRIPTPATH/postit "$fail"
      showError "$fail"
   fi
}

# A simple utility function to show the usage for the script
function showUsage {
   echo "$1  $2"
}


function timeCheck
{
   if [ -n ${stateFile} ]; then
   timeStamp=`date`
   echo "$timeStamp $*" >> $stateFile
   else
      echo "stateFile variable needs to be declared to use timeCheck"
      exit 1
   fi
}


function showError {
   OPTIND=0
   local _showusage="false"
   while getopts "h" OPTS
   do
      case $OPTS in
      h) _showusage="true"
      ;;
      ?) showError "bad option $OPT for showError function"
      esac
   done
   shift $(( OPTIND - 1 ))
   echo -e "[ERROR] $@" 1>&2
   alert "$@"
   if [ "$_showusage" = "true" ]; then
      showUsage
   fi
   debug "Unsuccessful end"
   exit 1
}

# Trims the leading and trailing spaces
function trim {
   local ltrim=${1#* }
   local rtrim=${ltrim%* }
   echo ${rtrim}
}

function incrementCounter {
   local xIdx=$1
   # Remove any leading zeros
   xIdx=$(echo ${xIdx}|sed 's/^0*//')
   # Add one to the value
   xIdx=$(( ${xIdx} + 1 ))
   # Put the leading zeros back
   xIdx=$(printf "%04d" $xIdx)
   # Now, we have a new name.
   echo $xIdx
}

function myfunction {
   echo "[FUNCTIONTEST] $*"
}

function scriptCount {
   $_debug && export $_debug
   $SCRIPTPATH/scriptcount $1
}

function doOptions {
   while getopts "hv" OPTION
   do
      case $OPTION in
         h) showUsage
            exit 0
         ;;
         v) echo "commonFunctions setting debug"
            _debug=true
         ;;
      esac
   done
}

# hasArguement can be used in handleOptions to verify if
# an argument is supplied for an option
function hasArgument {
   if [ -z $2 ]; then
      showError "Option $1 requires an argument"
   fi
}

# The new handleOptions function that will handle both
# short and long options. There are some caveats in that
# concatenated options are not tolerated i.e. -abc should 
# be provided as -a -b -c.
# On completion, the _ARGS variable will be set with the
# remainging command line arguments to the command.
function handleOptions {
   cl=$(getopt -o vho:t: --long verbose,help,one:,two: -n optionTest -- "$@")
   debug $cl
   eval set -- "$cl"
   while true; do
      debug "$1 of $*"
      case "$1" in 
      -h | --help ) debug "Help was chosen"; showUsage; exit ;;
      -v | --verbose ) debug "verbose was chosen"; _debug=true; shift ;;
      -- ) debug "handleOptions"; shift; break ;;
      -*) debug "handleOptions $1"
          if [ -z $1 ]; then
             break
          else
             showError "Option $1 is an invalid"
         fi
      ;;
      *) debug "handleOptions $1"; break;;
      esac
   done
   debug "remaining ARGS=$*"
   __ARGS=$*
}

# Get the configuration properties from the configuration 
# file if one is specified on the command line. If not
# or if the configuration file is not complete, then
# prompt for the missing properties.
#
# configFile | NONE - To specifiy if there is a 
#                     configuration file name available
#                     those values will be used first.
# propNames         - An array containing a list of 
#                     environment variables to be set.
#                     if the environment variable is 
#                     already set, i.e defined in the 
#                     properties file then it will be 
#                     skipped. If i is not set, then it
#                     will be prompted for.
#
# Note: When specifing the environment varaibles to be
#       set, a name ending in ":S" will be treated as 
#       silent and will not be echoed when prompted for.
function doGetConfig {
   debug "========== doGetConfig START =========="
   configFile="$1"
   shift
   if [ "${configFile}" != "NONE" ]; then
      debug "The config file is $configFile"
      if [ ! -f "${configFile}" ]; then
         debug "********** doGetConfig END **********"
         showError "The configuration file \"${configFile}\" can not be found!"
      fi
      local cfg=$(grep -v "#" $configFile | sed '/^$/ d' |tr "\n" ", " )
      debug "The existing configuration: $cfg"
      . ${configFile}
   fi
   props=(${!1})
   propsc=${#props[@]}
   # Iterate through the property names and 
   for (( i=0;i<$propsc;i++ )); do
      # Read the variable value pointed to by ${props[${i}]
      # into paramVal. Where the param name has ":S", then 
      # the read will be performed with the -s (silent) option.

      # local paramName=$(echo "${props[${i}]}" | awk -F: '{print $1}' )
      # local mode=$(echo "${props[${i}]}" | awk -F: '{print $2}' )

      # 12.08.14 - New feature considered... VAR [: mode] [/ default]
      # This consideres to add an additional qualifier of a "/" to 
      # present a default value. The variable should still be prompted
      # for but the option of the default value should be given. On 
      # pressing return without entering anything, the default value 
      # will be used in its place. Silent mode should work as is.

      # var:S
      # var/default
      # var:S/default

      local paramName=""
      local mode=""
      local defaultValue=""
      local propertyString="${props[${i}]}"

      getPropertyCharacteristics $propertyString characteristics

      local chararray=($characteristics)
      paramName=${chararray[0]}
      mode={$chararray[1]}
      defaultValue=${chararray[2]}
      if [ "${mode}"=="X" ]; then
         mode=""
      fi
      debug "paramName=$paramName mode=$mode defaultValue=$defaultValue"
      eval paramVal=${!paramName}
      if [ -z "${paramVal}" ]; then
         # The parameter was not specified in the configuration 
         # file (or no configuration file was specified), so 
         # prompt for the value
         if [ "${mode}" == "S" ]; then
            mode="-s"
         fi

         local defaultPrompt=""
         if [ "${mode}" != "-s" ] && [ "${defaultValue}" != "" ]; then
            defaultPrompt="[${defaultValue}]"
         fi

         echo -e "Enter a value for \"${paramName}\" ${defaultPrompt} \c "
         read ${mode}
         echo ""
         if [ "${REPLY}" != "" ]; then
            paramVal="${REPLY}"
            debug "Parameter value is ${paramVal}"
            # Set the read value to the respective environment variable.
            eval ${paramName}=${paramVal}
            eval p2=${!paramName}
            debug "Reassigned value ${paramName}=${p2}"
         else
            debug "No reply was given. Apply the default, if provided"
            if [ "${defaultValue}" != "" ]; then
               paramVal="${defaultValue}"
               eval ${paramName}=${paramVal}
               eval p2=${!paramName}
               debug "Reassigned default value ${paramName}=${p2}"
            fi
         fi
      fi
      debug "${paramName}=${!paramName}"
   done
   debug "********** doGetConfig END **********"
}

function __doGetConfig {
   debug "doGetConfig START"
   configFile="$1"
   shift
   if [ "${configFile}" != "NONE" ]; then
      debug "The config file is $configFile"
      if [ ! -f "${configFile}" ]; then
         showError "The configuration file \"${configFile}\" can not be found!"
      fi
      local cfg=$(grep -v "#" $configFile | sed '/^$/ d' |tr "\n" ", " )
      debug "The existing configuration: $cfg"
      . ${configFile}
   fi
   props=(${!1})
   propsc=${#props[@]}
   # Iterate through the property names and 
   for (( i=0;i<$propsc;i++ )); do
      # Read the variable value pointed to by ${props[${i}]
      # into paramVal. Where the param name has ":S", then 
      # the read will be performed with the -s (silent) option.

      # local paramName=$(echo "${props[${i}]}" | awk -F: '{print $1}' )
      # local mode=$(echo "${props[${i}]}" | awk -F: '{print $2}' )

      # 12.08.14 - New feature considered... VAR [: mode] [/ default]
      # This consideres to add an additional qualifier of a "/" to 
      # present a default value. The variable should still be prompted
      # for but the option of the default value should be given. On 
      # pressing return without entering anything, the default value 
      # will be used in its place. Silent mode should work as is.

      # var:S
      # var/default
      # var:S/default

      local paramName=""
      local mode=""
      local defaultValue=""
      local propertyString="${props[${i}]}"

      local hasQualifier=$(expr index "${propertyString}" ":=" )
      debug "hasQualifier=${hasQualifier}"

      if [ "${hasQualifier}" -gt 0 ]; then
         # paramName=$(echo "${props[${i}]}" | awk -F: '{print $1}' )
         # Locate the fist of the qualifiers and remove the 
         # substring for the property name.
         local pos=$(expr index "${propertyString}" ":=")
         pos=$(( pos - 1))
         paramName=${propertyString:0:${pos}}
         propertyString=${propertyString:pos}
         debug "paramName as extracted from the qualifier: ${paramName}"
         local checkQualifiers=true
         while [ ${checkQualifiers} == true ]; do
            debug "Remainging part of propertyString: ${propertyString}"
            # At this point, we still don't know if this is :S=default,
            # :S or =default.
            pos=$(expr index "${propertyString}" ":=")
            debug "Looking for := in ${propertyString} and found $pos"
            if [ ${pos} -gt 0 ]; then
               pos=$(( pos - 1))
               debug "checking ${propertyString:pos:1} == : "
               if [ "${propertyString:pos:1}" == ":" ]; then
                  # mode=$(echo "${propertyString}" | awk -F: '{print $2}' )
                  mode=${propertyString:$(( pos + 1)):1}
                  debug "mode as extracted from qualifier: ${mode}"
               fi
               debug "checking ${propertyString:pos:1} == = "
               if [ "${propertyString:pos:1}" == "=" ]; then
                  defaultValue=$(echo "${propertyString}" | awk -F= '{print $2}' )
                  debug "defaultValue as extracted from qualifier: ${defaultValue}"
               fi
               propertyString=${propertyString:$(( pos + 1 ))}
            else
               checkQualifiers=false
            fi
         done
      else
            paramName=${propertyString}
      fi

      debug "paramName=$paramName mode=$mode"
      eval paramVal=${!paramName}
      if [ -z "${paramVal}" ]; then
         # The parameter was not specified in the configuration 
         # file (or no configuration file was specified), so 
         # prompt for the value
         if [ "${mode}" == "S" ]; then
            mode="-s"
         fi

         local defaultPrompt=""
         if [ "${mode}" != "-s" ] && [ "${defaultValue}" != "" ]; then
            defaultPrompt="[${defaultValue}]"
         fi

         echo -e "Enter a value for \"${paramName}\" ${defaultPrompt} \c "
         read ${mode}
         echo ""
         if [ "${REPLY}" != "" ]; then
            paramVal="${REPLY}"
            debug "Parameter value is ${paramVal}"
            # Set the read value to the respective environment variable.
            eval ${paramName}=${paramVal}
            eval p2=${!paramName}
            debug "Reassigned value ${paramName}=${p2}"
         else
            debug "No reply was given. Apply the default, if provided"
            if [ "${defaultValue}" != "" ]; then
               paramVal="${defaultValue}"
               eval ${paramName}=${paramVal}
               eval p2=${!paramName}
               debug "Reassigned default value ${paramName}=${p2}"
            fi
         fi
      fi
      debug "${paramName}=${!paramName}"
   done
   debug "doGetConfig END"
}


#
# remoteCopy [ -r ] fromLocation host toLocation [ mode ]
# 
# Wildecards should be quoted.
#
# mode ::= "scp" | "nfs"
# scp is the default
#
# -r     Receusive copy
#
function remoteCopy {
   local recursive=""
   while getopts "r" OPTS
   do
      case $OPTS in
      r) recursive="-r"
      ;;
      ?) showError "bad option $OPT for remoteCopy function"
      esac
   done
   shift $(( OPTIND - 1 ))

   local from=$1
   shift
   local host=$1
   shift
   local location=$1
   shift
   local mode=$1

   mode=${mode:="scp"}

   debug "remote copy from=${from} host=${host} location=${location} mode=${mode} recursive=$recursive"
   case $mode in
      scp) 
      debug "rcp ${recirsive} ${from} ${host}:${location}"
      scp ${recursive} ${from} ${host}:${location}
      ;;
      nfs) 
      debug "cp ${recursive} ${from} /net/${host}/${location}"
      cp ${recursive} ${from} /net/${host}/${location}
      ;;
      ftp) debug "ftp is not implemented"
      ;;
   esac
}

# Determine the extentsion from a file
function extension {
   local fullname=$1
   local fname=$(basename "$fullname")
   local __result=${fname##*.}
   echo ${__result}
}

# Get the base file name without the extension
function filename {
   local fullname=$1
   local fname=$(basename "$fullname")
   local __result=${fname%.*}
   echo ${__result}
}

# Get the full path to a file
function path {
   local fullname=$1
   local __result=$(dirname $fullname)
   echo ${__result}
}

function toUpper {
   local result=$( echo "${1}" | tr  '[:lower:]' '[:upper:]'  )
   echo $result
}

function toLower {
   local result=$( echo "${1}" | tr  '[:upper:]'  '[:lower:]' )
   echo $result
}

# The default propertyNames for usage in doGetConfig is the _mandatoryproperties 
# variable. Although doGetConfig has no direct dependancy on this variable
# it simplifies script that use this common function library to conform to using
# it.
function getPropertyNames {
   if [ -z "$_mandatoryproperties" ]; then
      showError "The _mandatoryproperties variable has not been set. getPropertyNames must have this set to work"
   fi
   echo $_mandatoryproperties
}

# Property Characteristcs interprets the property string for doGetConfig function.
# The properties can have addition characteristics associated with them in order
# to provide default values and a silen mode i.e. for passwords.
#
# property - Single name, not in silent mode and no default value
# property:S - Silent mode. If the value is not already supplied, this will be
#              prompted for but in silent mode i.e. for passwords.
# property=default - The default value will be used if the value is not already
#                    provided and there was no alternate value provided when 
#                    prompted for.
# property:S=default - The default value to be used if no alternate value is
#                      provided when prompted for. When prompted, it will be in
#                      silent mode. It makes no sense to have a password in clear
#                      text as a default and then prompt for it in silent mode.
#                      However, it is added as a possibility.
function getPropertyCharacteristics {
   local propertyString=$1
   shift
   local characteristicsvar=$1
   debug "prop=${prop}"
   local paramName=""
   local mode="X"
   local defaultValue=""

   local hasQualifier=$(expr index "${propertyString}" ":=" )
   debug "hasQualifier=${hasQualifier}"

   if [ "${hasQualifier}" -gt 0 ]; then
      # paramName=$(echo "${props[${i}]}" | awk -F: '{print $1}' )
      # Locate the fist of the qualifiers and remove the 
      # substring for the property name.
      local pos=$(expr index "${propertyString}" ":=")
      pos=$(( pos - 1))
      paramName=${propertyString:0:${pos}}
      propertyString=${propertyString:pos}
      debug "paramName as extracted from the qualifier: ${paramName}"
      local checkQualifiers=true
      while [ ${checkQualifiers} == true ]; do
         debug "Remainging part of propertyString: ${propertyString}"
         # At this point, we still don't know if this is :S=default,
         # :S or =default.
         pos=$(expr index "${propertyString}" ":=")
         debug "Looking for := in ${propertyString} and found $pos"
         if [ ${pos} -gt 0 ]; then
            pos=$(( pos - 1))
            debug "checking ${propertyString:pos:1} == : "
            if [ "${propertyString:pos:1}" == ":" ]; then
               # mode=$(echo "${propertyString}" | awk -F: '{print $2}' )
               mode=${propertyString:$(( pos + 1)):1}
               debug "mode as extracted from qualifier: ${mode}"
            fi
            debug "checking ${propertyString:pos:1} == = "
            if [ "${propertyString:pos:1}" == "=" ]; then
               defaultValue=$(echo "${propertyString}" | awk -F= '{print $2}' )
               debug "defaultValue as extracted from qualifier: ${defaultValue}"
            fi
            propertyString=${propertyString:$(( pos + 1 ))}
         else
            checkQualifiers=false
         fi
      done
   else
      paramName=${propertyString}
   fi
   # echo "${paramName} ${mode} ${defaultValue}"
   local cv="${paramName} ${mode} ${defaultValue}"
   debug "$characteristicsvar=${cv}"
   eval ${characteristicsvar}="'${cv}'"
}

# Used for the showUsage function within a script, this function will
# get the value of _manditoryproperties and display them as a comma
# seperated list. The showuUsge function that is calling this
# should use $(displayProperties | column -s ',' -t) to display the list
# as a neat set of columns.
function displayProperties {
   debug "========== displayProperties =========="
   local props=($(getPropertyNames))
   local propCount=${#props[@]}
   debug "propCount=${propCount}"
   echo -e "Name,Mode,Default value"
   echo -e "----,----,-------------"
   for (( i=0;i<${propCount};i++ )); do
      local prop=${props[${i}]}
      debug "prop=${prop}"
      local charcatersistics=""
      getPropertyCharacteristics ${prop} characteristics
      debug "returned characteristics=${characteristics}"
      local cc=$(echo ${characteristics} | sed -e "s/ /,/g" )
      local cc=$(echo ${cc} | sed -e "s/,X/, /g" )
      echo -e "${cc} "
   done
   debug "********** displayProperties **********"
}

function alert {
 local message=$1
 notify-send --urgency=low -i terminal Note "$message"
}


