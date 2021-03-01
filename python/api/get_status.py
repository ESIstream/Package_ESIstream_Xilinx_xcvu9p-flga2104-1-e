#!/usr/bin/env python
import os
import sys
import time
from ev12aq600 import ev12aq600

app=ev12aq600()
app.start_serial()


ret=app.get_status()
print("-- Status: "+str(hex(ret)))

ret=app.get_hdl_version()
print("-- HDL version: "+str(hex(ret)))

app.deactivate_ev12aq600_rstn()

print ("-- Get Chip ID (2324):")
app.spi_ss_ev12aq600()
value=app.ev12aq600_get_register_value(0x0011) # Chip ID (0x914, hex) (2324, dec)

if value == 2324:
    print ("-- (v) Chip ID valid")
else:
    print (value)
    print ("-- (e) Chip ID error")

app.stop_serial()

