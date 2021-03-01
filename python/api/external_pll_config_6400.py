#!/usr/bin/env python
import os
import sys
import time
from ev12aq600 import ev12aq600

app=ev12aq600()

app.start_serial()
app.ev12aq600_rstn_pulse()
app.spi_ss_external_pll()
app.external_pll_configuration_6400()
app.ev12aq600_rstn_pulse()

time.sleep(0.5)
app.esistream_reset_pulse()

app.stop_serial()

