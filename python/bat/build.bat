@echo off
echo -- begin %0

CALL %1/vivado.bat -notrace -nojournal -nolog -mode batch -source %2 -tclargs %3

rem The Tcl source command allows the suppression of  Tcl command echoing by using the -notrace option.
echo -- end %0
