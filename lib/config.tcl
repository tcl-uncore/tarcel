# Config handler
#
# Copyright (C) 2015 Lawrence Woodman <lwoodman@vlifesystems.com>
#
# Licensed under an MIT licence.  Please see LICENCE.md for details.
#

package require configurator
namespace import configurator::*


::oo::class create ::tarcel::Config {
  variable config

  constructor {} {
    set config [dict create init {} archive [::tarcel::TarArchive new]]
  }

  method parse {script} {
    set selfObject [self object]
    set exposeCmds {
      foreach foreach
      glob glob
      if if
      lassign lassign
      list list
      llength llength
      lsort lsort
      regexp regexp
      regsub regsub
      set set
      string string
    }
    set slaveCmds [dict create \
      config [list ${selfObject}::my Config] \
      error [list ${selfObject}::my Error] \
      fetch [list ${selfObject}::my Fetch] \
      file [list ${selfObject}::my File] \
      find [list ${selfObject}::my Find] \
      get [list ${selfObject}::my Get] \
      import [list ${selfObject}::my Import] \
      tarcel [list ${selfObject}::my Tarcel]
    ]

    parseConfig -keys {} -exposeCmds $exposeCmds -slaveCmds $slaveCmds $script

    return $config
  }


  method load {filename} {
    set fd [open $filename r]
    set scriptIn [read $fd]
    set config [my parse $scriptIn]
    close $fd
    return $config
  }


  ########################
  # Private methods
  ########################

  method Tarcel {interp destination dotTarcelFilename args} {
    set startDir [pwd]
    set fd [open $dotTarcelFilename r]
    set dotTarcel "set args \[list $args\]\n"
    append dotTarcel [read $fd]
    close $fd

    set childConfig [::tarcel::Config new]
    cd [file dirname $dotTarcelFilename]

    try {
      set childConfigSettings [$childConfig parse $dotTarcel]
    } finally {
      cd $startDir
    }

    lassign [compiler::compile -nostartupcode $childConfigSettings] \
            startScript \
            tarball
    set tarcel [string cat $startScript $tarball]
    set archive [dict get $config archive]
    set childOutputFilename [
      file join $destination [dict get $childConfigSettings outputFilename]
    ]
    $archive importContents $tarcel $childOutputFilename
  }


  method Error {interp msg} {
    error $msg
  }

  method Config {interp command args} {
    set validVarnames {hashbang homepage init outputFilename version}
    switch $command {
      set {
        if {[llength $args] != 2} {
          return -code error \
                 "wrong # of arguments, should be: config set varName value"
        }
        lassign $args varName value
        if {$varName ni $validVarnames} {
          return -code error "invalid variable for config set: $varName"
        }
        dict set config $varName $value
      }

      default {
        return -code error "invalid config command: $command"
      }
    }
  }


  method Get {interp what args} {
    switch $what {
      packageLoadCommands { my GetPackageLoadCommands {*}$args }
      default {
        return -code error "invalid command: get $what $args"
      }
    }
  }


  method Import {interp importPoint files} {
    set archive [dict get $config archive]
    $archive importFiles $files $importPoint
  }


  method Fetch {interp importPoint files} {
    set archive [dict get $config archive]
    $archive fetchFiles $files $importPoint
  }


  method File {interp command args} {
    switch $command {
      dirname { return [::file dirname {*}$args] }
      join { return [::file join {*}$args] }
      tail { return [::file tail {*}$args] }
      default {
        return -code error "invalid command for file: $command"
      }
    }
  }


  method Find {interp type args} {
    switch $type {
      module { my FindModule {*}$args }
      default {
        return -code error "unknown find type: $type"
      }
    }
  }


  method FindModule {args} {
    lassign $args moduleName
    set requirements [lrange $args 1 end]
    set dirPrefix [regsub {^(.*?)([^:]+)$} $moduleName {\1}]
    set dirPrefix [regsub {::} $dirPrefix [file separator]]
    set tailModuleName [regsub {^(.*?)([^:]+)$} $moduleName {\2}]
    set foundModules [list]

    foreach path [::tcl::tm::path list] {
      set possibleModules [
        glob -nocomplain \
             -directory [file join $path $dirPrefix] \
             "$tailModuleName*.tm"
      ]
      foreach moduleFilename $possibleModules {
        set tailFoundModule [file tail $moduleFilename]
        set version [regsub {^(.*?)-(.*?)\.tm$} $tailFoundModule {\2}]
        if {[llength $requirements] >= 1 &&
            ![package vsatisfies $version {*}$requirements]} {
          continue
        }
        lappend foundModules [list $moduleFilename $version]
      }
    }

    if {[llength $foundModules] == 0} {
      return -code error "Module can't be found: $moduleName"
    }
    set latestModule [lindex [lsort -decreasing -index 1 $foundModules] 0]
    lassign $latestModule fullModuleFilename
    return $fullModuleFilename
  }


  method GetPackageLoadCommands {args} {
    lassign $args packageName
    set requirements [lrange $args 1 end]
    set numVersions [package versions $packageName]
    set validVersions [list]

    # Keep trying to find all versions of package until no new ones found
    while {1} {
      {*}[package unknown] $packageName
      set versions [package versions $packageName]
      set newNumVersions [llength $versions]
      if {$newNumVersions == $numVersions} {
        break
      }
      set numVersions $newNumVersions
    }
    if {[llength $requirements] >= 1} {
      foreach version $versions {
        if {[package vsatisfies $version {*}$requirements]} {
          lappend validVersions $version
        }
      }
    } else {
      set validVersions $versions
    }

    if {[llength $validVersions] == 0} {
      return {}
    }
    set bestVersion [lindex [lsort -decreasing $validVersions] 0]
    return [list [package ifneeded $packageName $bestVersion] $bestVersion]
  }

}
