#!/usr/bin/env python
import os
import sys
import time
from ev12aq600 import ev12aq600

app=ev12aq600()

app.start_serial()

app.spi_ss_ev12aq600()
app.ev12aq600_configuration_pattern0_mode()

app.stop_serial()

