package require Tcl 8.6
package require tcltest
namespace import tcltest::*

set ThisScriptDir [file dirname [info script]]
set RootDir [file join $ThisScriptDir ..]
set LibDir [file join $ThisScriptDir .. lib]
set FixturesDir [file normalize [file join $ThisScriptDir fixtures]]
set TarcelDir [file normalize [file join $ThisScriptDir ..]]


source [file join $ThisScriptDir "test_helpers.tcl"]

if {![TestHelpers::makeLibWelcome]} {
  puts stderr "Skipping test wrap-1 as couldn't build libwelcome"
  skip wrap-1
}


test wrap-1 {Ensure can 'package require' a module/tarcel that is made from a shared library} -setup {
  set startDir [pwd]
  set tempDir [TestHelpers::makeTempDir]

  cd [file join $FixturesDir libwelcome]
  exec tclsh [file join $TarcelDir tarcel.tcl] wrap \
      -o [file join $tempDir welcomefred.tcl] welcomefred.tarcel
} -body {
  exec tclsh [file join $tempDir welcomefred.tcl]
} -cleanup {
  cd $startDir
} -result {Welcome fred}


test wrap-2 {Ensure can wrap itself and then wrap something else} -setup {
  set tempDir [TestHelpers::makeTempDir]

  exec tclsh [file join $TarcelDir tarcel.tcl] wrap \
             -o [file join $tempDir t.tcl] \
             tarcel.tarcel
  exec tclsh [file join $tempDir t.tcl] wrap \
             -o [file join $tempDir h.tcl] \
             [file join $FixturesDir hello hello.tarcel]
} -body {
  exec tclsh [file join $tempDir h.tcl]
} -result {Hello bob, how are you?}


test wrap-3 {Ensure that output file is relative to pwd} -setup {
  set startDir [pwd]
  set tempDir [TestHelpers::makeTempDir]
  cd $tempDir

  exec tclsh [file join $TarcelDir tarcel.tcl] wrap \
             -o h.tcl \
             [file join $FixturesDir hello hello.tarcel]
} -body {
  file exists h.tcl
} -cleanup {
  cd $startDir
} -result 1


test wrap-4 {Ensure that output file isn't created if it already exists} -setup {
  set tempDir [TestHelpers::makeTempDir]

  exec tclsh [file join $TarcelDir tarcel.tcl] wrap \
             -o [file join $tempDir h.tcl] \
             [file join $FixturesDir hello hello.tarcel]
} -body {
  try {
    exec tclsh [file join $TarcelDir tarcel.tcl] wrap \
               -o [file join $tempDir h.tcl] \
               [file join $FixturesDir hello hello.tarcel]
  } on error {result options} {}
  regsub {^(Error:.*: )(.*)(tmp.*tarcel_tests)(_\d+)(/h.tcl)$} $result {\1\3\5}
} -result "Error: output file already exists: [file join tmp tarcel_tests h.tcl]"


test wrap-5 {Ensure outputs an error if problem with .tarcel file} -setup {
  set tempDir [TestHelpers::makeTempDir]
} -body {
  try {
    exec tclsh [file join $TarcelDir tarcel.tcl] wrap \
        -o [file join $tempDir invalid.tcl] \
        [file join $FixturesDir invalid.tarcel]
  } on error {result options} {}
  set result
} -result "Error in [file join $FixturesDir invalid.tarcel]: invalid command name \"sset\""


test info-1 {Ensure that outputs an error if not a tarcel file} -setup {
} -body {
  try {
    exec tclsh [file join $TarcelDir tarcel.tcl] info \
               [file join $TarcelDir README.md]
  } on error {result options} {}
  set result
} -result "Error: invalid tarcel file: [file join $TarcelDir README.md]"


test info-2 {Ensure that output includes the tarcel version number that created a tarcel} -setup {
  set tempDir [TestHelpers::makeTempDir]
  exec tclsh [file join $TarcelDir tarcel.tcl] wrap \
             -o [file join $tempDir t.tcl] \
             tarcel.tarcel

} -body {
  set info [
    exec tclsh [file join $TarcelDir tarcel.tcl] info \
               [file join $tempDir t.tcl]
  ]
  set lines [split $info "\n"]
  foreach line $lines {
    if {[regexp {^Created with.*?arcel.*?version.*?\d+\.\d+.*?$} $line]} {
      return 1
    }
  }
  return 0
} -result 1


cleanupTests
