#!/usr/bin/env python
import os
import sys
import time
import datetime
import logging
logging.basicConfig(level=logging.DEBUG)
# DEBUG    | Detailed information, typically of interest only when diagnosing problems.
# INFO     | Confirmation that things are working as expected.
# WARNING  | An indication that something unexpected happened, or indicative of some problem in the near future (e.g. "disk space low"). The software is still working as expected.
# ERROR    | Due to a more serious problem, the software has not been able to perform some function.
# CRITICAL | A serious error, indicating that the program itself may be unable to continue running.

if  len(sys.argv) > 1:
    arg1= sys.argv[1]
else:
    arg1 = 0
    print("-------------------------------------------------------------")
    print("-- START of PYTHON BUILD.PY ARG without argument...")
    print("-- ")
    print("-- use 'python build.py prj' to create vivado project")
    print("-- use 'python build.py sim' to launch testbench simulation")
    print("-- use 'python build.py gen' to launch bitstream generation")
    print("-- use 'python build.py all'  to create vivado projects, launch testbench simulations and generate bitstream")
    print("-- ")
    print("-------------------------------------------------------------")
    sys.exit("-- exit on error: python script argument is missing...")
        
logging.debug(arg1)

# Get the current working directory:
cwd = os.getcwd()
logging.debug("Current working directory: %s", cwd)

# Get the current working durectory path (python_path):
cwdp = os.path.dirname(os.path.realpath(__file__))
logging.debug("Current working directory path: %s", cwdp)

# Create .bat file directory path:
bat_path = cwdp + "\\bat\\"
logging.debug("bat path: %s", bat_path)

# Create vivado.bat (vivado 2019.1) directory path
vivado_path = "C:\\Xilinx\\Vivado\\2019.2\\bin"

# Package reference:
package_reference = "xilinx_vu9p"

# ---------------------------------------------------------------------------------------------
# HDL implementation list:
# [[hdl implementation script name, hw_project_list[0], hw_project_list[1], ...],
# [...]]
# when the value of the 2nd and 3rd column is > 1, the related HDL implementaton is simulated and it also defines the simulation run time [us] else the HDL implementation is not simulated.
# ---------------------------------------------------------------------------------------------
# Example of hardware and implementation list:
# ---------------------------------------------------------------------------------------------
# hw_project_list = ["vivado_rx_aq600", "vivado_txrx_xm107"]
# implementation_list = [["script_16b.tcl"   , 10, 0],
#                        ["script_32b.tcl"   , 10, 0],
#                        ["script_64b.tcl"   , 10, 0],
#                        ["script_16b_dl.tcl", 0,  10],
#                        ["script_32b_dl.tcl", 10, 10],
#                        ["script_64b_dl.tcl", 10, 10]]
# ---------------------------------------------------------------------------------------------
#
# Valid implementation:
#hw_project_list = ["vivado_txrx_xm107", "vivado_rx_ev12aq60x"]
#implementation_list = [["script_16b_dl.tcl", 10, 0],
#                       ["script_32b_dl.tcl", 10, 10],
#                       ["script_64b_dl.tcl", 10, 10]]
#
hw_project_list = ["vivado_rx_ev12aq60x_qsfp"]
implementation_list = [["script_64b_dl.tcl", 17, 0]]

tb_log_path = "C:\\vw\\" + package_reference + "\\tb_log.txt" 

hw_id = 0
for hw in hw_project_list:
  logging.debug(hw)
  hw_id = hw_id + 1
  tcl_path = ""
  for imp in implementation_list:
      # Work only on enabled implementations:
      if imp[hw_id]:
          logging.debug(imp)
          tcl_path = cwdp + "\\..\\" + hw + "\\" + imp[0]
          logging.debug(tcl_path)
          if arg1 == "prj" or arg1 == "all":
              # Launch bat file to create vivado project and generate simulation scripts (compile.bat, elaborate.bat and simulate.bat).
              # In a batch file use CALL is better than use START because CALL waits for the end of process execution to continue !
              build_enable = str(0)
              os.system(bat_path + "build.bat " + vivado_path + " " + tcl_path + " " + build_enable + " " + build_enable)
              logging.debug("end of bat file creating vivado project and generating simulation scripts (compile.bat, elaborate.bat and simulate.bat).")
              logging.debug("end of build %s %s", hw, imp[0])
              print("-------------------------------------------------------------")
              print("-- VIVADO PROJECT CREATED...")
              print("-------------------------------------------------------------")
          if arg1 == "sim" or arg1 == "all":
              # Open testbench log file in append mode, or create it if it does not exist:
              tb_log = open(tb_log_path, "a+")
              tb_log_text = "\r\n" + str(datetime.datetime.now()) + ": " + package_reference + ", " + hw + ", " + imp[0] + " [sim] \r\n" 
              tb_log.write(tb_log_text)
              tb_log.close() 
              # Launch simulation only
              sim_enable = str(imp[hw_id])
              os.system(bat_path + "build.bat " + vivado_path + " " + tcl_path + " " + sim_enable)
              logging.debug("end of sim %s %s", hw, imp[0])
              print("-------------------------------------------------------------")
              print("-- TESTBENCH SIMULATED...")
              print("-------------------------------------------------------------")
          if arg1 == "gen" or arg1 == "all":
              # Open testbench log file in append mode, or create it if it does not exist:
              tb_log = open(tb_log_path, "a+")
              tb_log_text = "\r\n" + str(datetime.datetime.now()) + ": " + package_reference + ", " + hw + ", " + imp[0] + " [gen]\r\n" 
              tb_log.write(tb_log_text)
              tb_log.close() 
              # Launch simulation only
              gen_enable = str(-1)
              os.system(bat_path + "build.bat " + vivado_path + " " + tcl_path + " " + gen_enable)
              logging.debug("end of gen %s %s", hw, imp[0])
              print("-------------------------------------------------------------")
              print("-- BISTREAM GENERATED...")
              print("-------------------------------------------------------------")
    
