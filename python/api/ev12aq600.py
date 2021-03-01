import os
import sys
import time
import serial
import logging

## CONSTANTS:
REG_NUMBER = 20 # Satus register can't be written (read only).
REG_AQ600_NUMBER = 2**16 # Satus register can't be written (read only).
REG_ADDRESS_LENGTH = 2
REG_DATA_LENGTH = 4
REG_HDL_VERSION_ADDRESS = 8
REG_SPI_FIFO_FLAGS_ADDRESS = 9
REG_SPI_RD_FIFO_ADDRESS = 10
REG_STATUS_ADDRESS = 255
REG_READ_MODE_ENABLE = 2**15 # Address field MSB high (bit 15).
SPI_SLAVE_EV12AQ600 = 0x0
SPI_SLAVE_EXTERNAL_PLL = 0x1
SYNC_MODE_NORMAL = 0x0
SYNC_MODE_TRAINING = 0x1
EV12AQ600_READ_OPERATION_MASK = 0x7FFF
EV12AQ600_WRITE_OPERATION_MASK = 0x8000

## CLASS:
class ev12aq600:
    def __init__(self):
        self.list = []    # creates a new empty list for each instance
        """
        Serial port object 
        """
        self.ser=""
        """
        FPGA registers base image 
        """
        self.reg_array = [0] * REG_NUMBER
        """
        ADC registers base image 
        """
        self.reg_aq600_array = [0] * REG_AQ600_NUMBER

    ##################################################################################################################################### 
    ## Serial port functions
    #####################################################################################################################################      
    def start_serial(self):
        """
        Open serial port (UART):
        The FPGA design embeds a UART slave which uses the following configuration:
        -	Baud rate: 115200 
        -	Data Bits: 8
        -	No parity
        """
        self.ser=serial.Serial("COM16", 115200, timeout=1)
        print("\r\n")
        print("--------------------------------------------------------")
        print("-- Serial communication opened... %s" %(self.ser.isOpen()))
        
    def stop_serial(self):
        """
        Close serial port (UART).
        """
        self.ser.close()
        print("-- Serial communication closed... %s" %(not self.ser.isOpen()))
        print("--------------------------------------------------------")
        print("\r\n")
     
    def write_register(self, address, data):
        """
        Parameters:
        * address : 15-bit : Positive integer.  
        * data :    32-bit : Positive integer. 
        The UART frames layer protocol defined here allows to perform read and write operations on the registers listed in the register map.
        write_registers takes FPGA register address and data to create the UART frames layer protocol write operation command:
        -	The most significant bit of the first transmitted byte (bit 7) must be set to 0 for write operation. 
        -	The bits 6 down to 0 of the first transmitted byte contain the bit 14 down to 8 of the register address.
        -	The second byte contains the bit 7 down to 0 of the register address. 
        -	The third byte contains the bit 31 down to 24 of the register data.
        -	The fourth byte contains the bit 23 down to 16 of the register data.
        -	The fifth byte contains the bit 15 down to 8 of the register data. 
        -	The sixth byte contains the bit 7 down to 0 of the register data.
        --
        -       Master write ----< Byte 1: 0 & Addr high >< Byte 2: Addr low >< Data byte 3 >< Data byte 2 >< Data byte 1 >< Data byte 0 >-------------------------------
        -       Master read  --------------------------------------------------------------------------------------------------------------------< ACK byte: 0xAC >-----
        """
        rcv=self.ser.read(self.ser.inWaiting()) 
        command = int(address).to_bytes(REG_ADDRESS_LENGTH, byteorder='big')
        command = command + int(data).to_bytes(REG_DATA_LENGTH,byteorder='big')
        self.ser.write(command)
        ack = self.wait_response() # Wait for slave acknowledgment ACK value = 0xAC (16) = 172 (10)
        return (int.from_bytes(ack, byteorder='big'))
    
    def read_register(self, address):
        """
        Parameters:
        * address : 15-bit : Positive integer.  
        The UART frames layer protocol defined here allows to perform read and write operations on the registers listed in the register map.
        read_registers takes FPGA register address to create the UART frames layer protocol read operation command:
        -	The most significant bit of the first transmitted byte (bit 7) must be set to 1 for read operation. 
        -	The bits 6 down to 0 of the first transmitted byte contain the bit 14 down to 8 of the register address.
        -	The second byte contains the bit 7 down to 0 of the register address. 
        Then, the master read the data and the acknowledgment word to check that the communication has been done correctly. The acknowledgment word is a single byte of value 0xAC (172 is the decimal value). 
        -	The third byte contains the bit 31 down to 24 of the register data.
        -	The fourth byte contains the bit 23 down to 16 of the register data.
        -	The fifth byte contains the bit 15 down to 8 of the register data. 
        -	The sixth byte contains the bit 7 down to 0 of the register data.
        --
        -       Master write ----< Byte 1: 1 & Addr high >---------------------------------------------------------------------------------------------------------
        -       Master read  -------------------------------< Byte 2: Addr low >< Data byte 3 >< Data byte 2 >< Data byte 1 >< Data byte 0 >< ACK byte: 0xAC >-----
        """
        command = (int(address)+REG_READ_MODE_ENABLE).to_bytes(REG_ADDRESS_LENGTH, byteorder='big')
        self.ser.write(command)
        data = self.ser.read(size=REG_DATA_LENGTH)
        ack = self.wait_response() # Wait for slave acknowledgment ACK value = 0xAC = 172
        return (int.from_bytes(data, byteorder='big'))

    def wait_response(self, wtext=b'\xAC', timeSleep=0.05, timeOut=1, timeDisplayEnable=False):
        """
        After sending a UART frames layer protocol write or read operation command allows waiting for the acknowledgment word: 
        - Hexadecimal: 0xAC 
        - Decimal: 172
        """
        ack=""
        waitResponse=True
        timeCntr=0
        while(waitResponse):
            time.sleep(timeSleep)
            timeCntr = timeCntr+timeSleep
            ack=self.ser.read(self.ser.inWaiting()) 
            if (wtext in ack):
                waitResponse=False
            elif (timeCntr == timeOut):
                ack='-- Error: wait_response "%s" timeout %ds'%(wtext, timeOut)
                waitResponse=False
            else:
                waitResponse=True
                if timeDisplayEnable:
                    logging.debug("...%ds"%(timeCntr))
        return ack

    def set_bit(self, reg_addr, reg_data_bit):
        """
        Parameters:
        * reg_addr     : 15-bit        : Positive integer, FPGA register address.   
        * reg_data_bit : range 0 to 31 : Positive integer, FPGA data register bit position.
        set_bit allows setting the register bit to 1. 
        For instance: 
        -        Register 2 value is 0x00000000
        Using set_bit(2, 2)
        -        Register 2 value becomes 0x00000004
        Also set FPGA registers base image (reg_array)
        """
        bit_slip = (0x1 << reg_data_bit)
        self.reg_array[reg_addr] = self.reg_array[reg_addr] | (bit_slip)
        self.write_register(reg_addr, self.reg_array[reg_addr])
        time.sleep(0.001)

    def unset_bit(self, reg_addr, reg_data_bit):
        """
        Parameters:
        * reg_addr     : 15-bit        : Positive integer, FPGA register address.   
        * reg_data_bit : range 0 to 31 : Positive integer, FPGA data register bit position.
        unset_bit allows setting the register bit to 0. 
        For instance: 
        -        Register 2 value is 0xFFFFFFFF
        Using set_bit(2, 2):
        -        Register 2 value becomes 0xFFFFFFFB
        Also set FPGA registers base image (reg_array)
        """
        bit_slip = (0x1 << reg_data_bit)
        self.reg_array[reg_addr] = self.reg_array[reg_addr] & (~bit_slip) 
        self.write_register(reg_addr, self.reg_array[reg_addr])
        time.sleep(0.001)

    #####################################################################################################################################   
    ## FPGA REGISTERS
    #####################################################################################################################################      
    ## REG 0
    def ramp_check_enable(self):
        reg_addr = 0
        reg_data_bit = 1
        self.set_bit(reg_addr, reg_data_bit)
        reg_data_bit = 0
        self.unset_bit(reg_addr, reg_data_bit)

    def pattern0_check_enable(self):
        reg_addr = 0
        reg_data_bit = 1
        self.unset_bit(reg_addr, reg_data_bit)
        reg_data_bit = 0
        self.unset_bit(reg_addr, reg_data_bit)
        
    ## REG 1
    def rx_prbs_enable(self):
        """
        Enable ESIstream RX IP PRBS decoding.
        """
        reg_addr = 1
        reg_data_bit = 0
        self.set_bit(reg_addr, reg_data_bit)
     
    ## REG 1
    def rx_prbs_disable(self):
        """
        Disable ESIstream RX IP PRBS decoding.
        """
        reg_addr = 1
        reg_data_bit = 0
        self.unset_bit(reg_addr, reg_data_bit)

    ## REG 2
    def esistream_reset_pulse(self):
        """
        Global software reset (active high reset).
        """
        reg_addr = 2
        reg_data_bit = 0
        self.set_bit(reg_addr, reg_data_bit)
        self.unset_bit(reg_addr, reg_data_bit)

    ## REG 2
    def rst_check_pulse(self):
        """
        Reset the RX data check module (active high reset).
        rst_check_pulse should be used after a sync pulse when the link is synchronized (lanes_ready high and data released) to check the decoded data are correct.  
        """
        reg_addr = 2
        reg_data_bit = 1
        self.set_bit(reg_addr, reg_data_bit)
        time.sleep(0.1)
        self.unset_bit(reg_addr, reg_data_bit)

    ## REG 2
    def ev12aq600_rstn_pulse(self):
        """
        EV12AQ600 ADC reset (active low reset). 
        """
        reg_addr = 2
        reg_data_bit = 2
        self.unset_bit(reg_addr, reg_data_bit)
        self.set_bit(reg_addr, reg_data_bit)

    def deactivate_ev12aq600_rstn(self):
        """
        Deactivate ADC reset (active low reset).
        """
        reg_addr = 2
        reg_data_bit = 2
        self.set_bit(reg_addr, reg_data_bit)
        
    def active_ev12aq600_rstn(self):
        """
        Activate ADC reset (active low reset).
        """
        reg_addr = 2
        reg_data_bit = 2
        self.unset_bit(reg_addr, reg_data_bit)
        
    ## REG 2
    def rx_sync_rst(self):
        """
        SYNC generator module reset (active high reset).
        """
        reg_addr = 2
        reg_data_bit = 3
        self.set_bit(reg_addr, reg_data_bit)
        self.unset_bit(reg_addr, reg_data_bit)

    ## REG 3
    def spi_ss_ev12aq600(self):
        """ 
        Select EV12AQ600 ADC SPI Slave 
        -	EV12AQ600 ADC when '0'
        -	External PLL LMX2592 when '1'
        """
        reg_addr = 3
        reg_data_bit = 0
        self.unset_bit(reg_addr, reg_data_bit)
        
    def spi_ss_external_pll(self):
        """ 
        Select External PLL LMX2592 SPI Slave 
        -	EV12AQ600 ADC when '0'
        -	External PLL LMX2592 when '1'
        """
        reg_addr = 3
        reg_data_bit = 0
        self.set_bit(reg_addr, reg_data_bit)

    ## REG 3
    def spi_start_pulse(self):
        """
        Send all SPI commands, pre-loaded in the SPI Master input FIFO, to the selected SPI slave.
        """
        reg_addr = 3
        reg_data_bit = 1
        self.set_bit(reg_addr, reg_data_bit)
        self.unset_bit(reg_addr, reg_data_bit)

    def spi_wr_fifo_in(self, spi_command):
        """
        Write a SPI command in the SPI Master input FIFO (FIFO IN).
        SPI FIFO IN data port. 
        To write data through SPI. SPI commands must be pre-loaded in the SPI Master input FIFO.
        Then spi_start bit to send all commands through SPI.
        """
        reg_addr = 3
        if (self.reg_array[reg_addr] & 0x00000001) == SPI_SLAVE_EV12AQ600:
            spi_command_mask = 0x0000FFFF
        else:
            spi_command_mask = 0x00FFFFFF
        #
        reg_addr = 4
        self.reg_array[reg_addr] = spi_command & spi_command_mask
        self.write_register(reg_addr, self.reg_array[reg_addr])

    ## REG 5
    def sync_mode_training(self):
        """
        Set SYNC Counter in training mode.
        """
        reg_addr = 5
        reg_data_bit = 0
        self.set_bit(reg_addr, reg_data_bit)
        
    def sync_mode_normal(self):
        """
        Set SYNC Counter in normal mode.
        """
        reg_addr = 5
        reg_data_bit = 0
        self.unset_bit(reg_addr, reg_data_bit)
    
    ## REG 6
    def sync_pulse(self):
        """
        Generate the SYNC pulse to synchronize the ESIstram serial link. 
        When send_sync is set to high, the SYNC generator module detects the rising 
        edge of the send_sync signal 
        and starts sending the SYNC pulse both to the ESIstream RX IP and to the ADC. 
        The SYNC pulse also starts the SYNC counter. 
        """
        reg_addr = 6
        reg_data_bit = 0
        self.set_bit(reg_addr, reg_data_bit)
        self.unset_bit(reg_addr, reg_data_bit)

    def set_sync_mode_to_manual(self):
        reg_addr = 6
        reg_data_bit = 1
        self.set_bit(reg_addr, reg_data_bit)

    def set_sync_mode_to_auto(self):
        reg_addr = 6
        reg_data_bit = 1
        self.unset_bit(reg_addr, reg_data_bit)   

    ## REG 7
    """ Not yet implemented """
    
    ## REG 8
    def get_hdl_version(self):
        """ 
        Get HDL firmware version
        """
        #print ("-- Get status value...")
        rcv = self.read_register(REG_HDL_VERSION_ADDRESS)
        return rcv

    ## REG 9
    #REG_SPI_FIFO_FLAGS_ADDRESS = 9
    def get_spi_fifo_flags(self):
        """
        Read SPI Master FIFO flags.
        -       bit 0 : SPI Master input FIFO full flag. Input FIFO is full when '1'
        -       bit 1 : SPI Master output FIFO empty flag. Output FIFO is empty when '0'
        """
        #print ("-- Get status value...")
        rcv = self.read_register(REG_SPI_FIFO_FLAGS_ADDRESS)
        return rcv
    
    ## REG 10
    #REG_SPI_RD_FIFO_ADDRESS = 10
    def get_spi_fifo_rd_dout(self):
        """
        Read a SPI command in the SPI Master output FIFO (FIFO OUT).
        SPI Master output FIFO data port. 
        Data read from SPI are stored in this FIFO. 
        After a SPI read operation data should be flushed performing UART read operation on this register until the output FIFO empty register goes low.
        """
        #print ("-- Get status value...")
        rcv = self.read_register(REG_SPI_RD_FIFO_ADDRESS)
        return rcv
    
    ## REG 11
    """ Not yet implemented """
    
    ## REG 12
    """ Not yet implemented """
    
    ## REG 15
    def hw_adc_power_enable(self):
        reg_addr = 15
        reg_data_bit = 0
        self.set_bit(reg_addr, reg_data_bit)

    def hw_adc_power_disable(self):
        reg_addr = 15
        reg_data_bit = 0
        self.unset_bit(reg_addr, reg_data_bit)
    
    def hw_pll_enable(self):
        reg_addr = 15
        reg_data_bit = 1
        self.set_bit(reg_addr, reg_data_bit)

    def hw_pll_disable(self):
        reg_addr = 15
        reg_data_bit = 1
        self.unset_bit(reg_addr, reg_data_bit)

    def hw_select_sync_fpga(self):
        reg_addr = 15
        reg_data_bit = 2
        self.unset_bit(reg_addr, reg_data_bit)
        reg_data_bit = 12
        self.set_bit(reg_addr, reg_data_bit)

    ## REG 255
    def get_status(self):
        """
        Reserved for debug 
        """
        rcv = self.read_register(REG_STATUS_ADDRESS)
        return rcv

    def wait_spi_output_fifo_not_empty(self, timeSleep=0.05, timeOut=5, timeDisplayEnable=False):
        #def wait_response(self, wtext=b'\xAC', timeSleep=0.05, timeOut=1, timeDisplayEnable=False):
        """
        Read SPI Master FIFO flags.
        -       bit 0 : SPI Master input FIFO full flag. Input FIFO is full when '1'
        -       bit 1 : SPI Master output FIFO empty flag. Output FIFO is empty when '0'
        """
        fifo_flags=0
        fifo_empty=0
        waitResponse=True
        timeCntr=0
        while(waitResponse):
            time.sleep(timeSleep)
            timeCntr = timeCntr+timeSleep
            fifo_flags=self.get_spi_fifo_flags()
            fifo_empty = (fifo_flags & 0x0002) >> 1
            if (fifo_empty == 0):
                # output fifo not empty
                waitResponse=False
            elif (timeCntr == timeOut):
                ack='-- Error: wait_response "%s" timeout %ds'%(wtext, timeOut)
                waitResponse=False
            else:
                waitResponse=True
                if timeDisplayEnable:
                    logging.debug("...%ds"%(timeCntr))
        return fifo_empty
    
    #####################################################################################################################################   
    ## EV12AQ600 registers
    ##################################################################################################################################### 
    def set_aq600_bit(self, reg_addr, reg_data_bit):
        """
        Parameters:
        * reg_addr     : positive integer : Register address, see EV12AQ600 datasheet.  
        * reg_data_bit : positive integer : FPGA data register bit position, see EV12AQ600 datasheet.  
        set_aq600_bit allows setting the register bit to 1. 
        For instance: 
        -        Register 2 value is 0x00000000
        Using set_bit(2, 2)
        -        Register 2 value becomes 0x00000004
        Also set ADC registers base image (reg_aq600_array)
        """
        bit_slip = (0x1 << reg_data_bit)
        self.reg_aq600_array[reg_addr] = self.reg_aq600_array[reg_addr] | (bit_slip)
        
    def unset_aq600_bit(self, reg_addr, reg_data_bit):
        """
        Parameters:
        * reg_addr     : positive integer : Register address, see EV12AQ600 datasheet.  
        * reg_data_bit : positive integer : FPGA data register bit position, see EV12AQ600 datasheet.  
        unset_aq600_bit allows setting the register bit to 0. 
        For instance: 
        -        Register 2 value is 0xFFFFFFFF
        Using set_bit(2, 2)
        -        Register 2 value becomes 0xFFFFFFFB
        Also set ADC registers base image (reg_aq600_array)
        """
        bit_slip = (0x1 << reg_data_bit)
        self.reg_aq600_array[reg_addr] = self.reg_aq600_array[reg_addr] & (~bit_slip) 
        
    def spi_wr_fifo_aq600(self, reg_addr):
        """
        Parameters:
        * reg_addr : positive integer : EV12AQ600 ADC register address, see datasheet
        spi_wr_fifo_aq600 loads address word first and then data word in SPI Master 
        input FIFO to write ADC register identified by the address value.
        """
        # Check spi slave select, if external pll then changer for ev12aq600 adc.
        if (self.reg_array[3] & 0x00000001) == SPI_SLAVE_EXTERNAL_PLL:
            self.spi_ss_ev12aq600()
        # Load register address in spi master input fifo
        self.spi_wr_fifo_in(reg_addr)
        # Load register data in spi master input fifo
        self.spi_wr_fifo_in(self.reg_aq600_array[reg_addr])

    def ev12aq600_configuration_ramp_mode(self):
        reg_addr = 0x008B0A
        reg_data_bit = 0
        self.set_aq600_bit(reg_addr, reg_data_bit)
        ## Load spi master fifo in with configuration data
        self.spi_wr_fifo_aq600(reg_addr)
        
        reg_addr = 0x008B07
        reg_data_bit = 0
        self.set_aq600_bit(reg_addr, reg_data_bit)
        reg_data_bit = 1
        self.set_aq600_bit(reg_addr, reg_data_bit)
        reg_data_bit = 2
        self.set_aq600_bit(reg_addr, reg_data_bit)
        ## Load spi master fifo in with configuration data
        self.spi_wr_fifo_aq600(reg_addr)
        
        ## Start spi write operation...
        self.spi_start_pulse()

    def ev12aq600_configuration_normal_mode(self):
        reg_addr = 0x008B0A
        reg_data_bit = 0
        self.unset_aq600_bit(reg_addr, reg_data_bit)
        ## Load spi master fifo in with configuration data
        self.spi_wr_fifo_aq600(reg_addr)
        
        reg_addr = 0x008B07
        reg_data_bit = 0
        self.set_aq600_bit(reg_addr, reg_data_bit)
        reg_data_bit = 1
        self.set_aq600_bit(reg_addr, reg_data_bit)
        reg_data_bit = 2
        self.set_aq600_bit(reg_addr, reg_data_bit)
        ## Load spi master fifo in with configuration data
        self.spi_wr_fifo_aq600(reg_addr)
        
        ## Start spi write operation...
        self.spi_start_pulse()
        
    def ev12aq600_configuration_pattern0_mode(self):
        reg_addr = 0x008B0A
        reg_data_bit = 0
        self.unset_aq600_bit(reg_addr, reg_data_bit)
        ## Load spi master fifo in with configuration data
        self.spi_wr_fifo_aq600(reg_addr)
        
        reg_addr = 0x008B07
        reg_data_bit = 0
        self.set_aq600_bit(reg_addr, reg_data_bit)
        reg_data_bit = 1
        self.unset_aq600_bit(reg_addr, reg_data_bit)
        reg_data_bit = 2
        self.set_aq600_bit(reg_addr, reg_data_bit)
        ## Load spi master fifo in with configuration data
        self.spi_wr_fifo_aq600(reg_addr)

        ## Start spi write operation...
        self.spi_start_pulse()

    def ev12aq600_reset_sync_flag(self):
        # The flag is reset by writing at the SYNC_FLAG_RST register address:
        # bit [0] = 0 : reset the flag 
        reg_addr = 0x00000E | EV12AQ600_WRITE_OPERATION_MASK
        reg_data_bit = 0
        self.spi_wr_fifo_aq600(reg_addr)
        ## Start spi write operation...
        self.spi_start_pulse()
        
    def ev12aq600_get_sync_flag(self):
        # bit [0] = Indicate timing violation on SYNC
        # bit [0] = 0 : SYNC has been correctly recovered
        # bit [0] = 1 :Timing violation on SYNC 
        #print ("-- spi fifo flags values: "+str(spi_fifo_flags))
        reg_addr = 0x00000D & EV12AQ600_READ_OPERATION_MASK
        reg_data_bit = 0
        self.spi_wr_fifo_aq600(reg_addr)
        ## Start spi write operation...
        self.spi_start_pulse() 
        spi_fifo_flags = self.get_spi_fifo_flags()
        fifo_empty = self.wait_spi_output_fifo_not_empty()
        #print ("-- FIFO empty flag [1: empty, 0: not empty]: "+str(fifo_empty))
        #
        rcv = self.get_spi_fifo_rd_dout() 
        return rcv
    
    def ev12aq600_sync_sampling_on_negative_edge(self):
        # The flag is reset by writing at the SYNC_FLAG_RST register address:
        # bit [0] = 0 : reset the flag 
        reg_addr = 0x00000C | EV12AQ600_WRITE_OPERATION_MASK
        reg_data_bit = 0
        self.set_aq600_bit(reg_addr, reg_data_bit)
        self.spi_wr_fifo_aq600(reg_addr)
        ## Start spi write operation...
        self.spi_start_pulse()
        
    def ev12aq600_sync_sampling_on_positive_edge(self):
        # The flag is reset by writing at the SYNC_FLAG_RST register address:
        # bit [0] = 0 : reset the flag 
        reg_addr = 0x00000C | EV12AQ600_WRITE_OPERATION_MASK
        reg_data_bit = 0
        self.unset_aq600_bit(reg_addr, reg_data_bit)
        self.spi_wr_fifo_aq600(reg_addr)
        ## Start spi write operation...
        self.spi_start_pulse()
        
    def ev12aq600_get_register_value(self, addr):
        """
        
        """
        #Chip id @ 0x0011, should return 0x914 (hex) or 2324 (dec)  
        print ("addr = "+str(addr))
        spi_fifo_flags = self.get_spi_fifo_flags()
        #print ("-- spi fifo flags values: "+str(spi_fifo_flags))
        reg_addr = addr & EV12AQ600_READ_OPERATION_MASK
        reg_data_bit = 0
        self.spi_wr_fifo_aq600(reg_addr)
        ## Start spi write operation...
        self.spi_start_pulse() 
        spi_fifo_flags = self.get_spi_fifo_flags()
        #print ("-- spi fifo flags values: "+str(spi_fifo_flags))
        rcv = self.get_spi_fifo_rd_dout()
        spi_fifo_flags = self.get_spi_fifo_flags()
        #print ("-- spi fifo flags values: "+str(spi_fifo_flags))
        return rcv
    
    #####################################################################################################################################  
    ## External PLL LMX2592
    ##################################################################################################################################### 
    def external_pll_configuration_6400(self):
        """
        Configure external PLL LMX2592 RFOUT A to generate a 6.4 GHz ADC Master CLK.
        1- Preload all SPI commands in the SPI Master input FIFO.
        2- Send all commands sending a spi_start pulse. 
        """
        self.spi_wr_fifo_in(0x00221E)
        self.spi_wr_fifo_in(0x400077)
        self.spi_wr_fifo_in(0x3E0000)
        self.spi_wr_fifo_in(0x3D0001)
        self.spi_wr_fifo_in(0x3B0000)
        self.spi_wr_fifo_in(0x3003FC)
        self.spi_wr_fifo_in(0x2F08CF)
        self.spi_wr_fifo_in(0x2E17A3)
        self.spi_wr_fifo_in(0x2D0000)
        self.spi_wr_fifo_in(0x2C0000)
        self.spi_wr_fifo_in(0x2B0000)
        self.spi_wr_fifo_in(0x2A0000)
        self.spi_wr_fifo_in(0x2903E8)
        self.spi_wr_fifo_in(0x280000)
        self.spi_wr_fifo_in(0x278204)
        self.spi_wr_fifo_in(0x260040)
        self.spi_wr_fifo_in(0x254000)
        self.spi_wr_fifo_in(0x240811)
        self.spi_wr_fifo_in(0x23021F)
        self.spi_wr_fifo_in(0x22C3EA)
        self.spi_wr_fifo_in(0x212A0A)
        self.spi_wr_fifo_in(0x20210A)
        self.spi_wr_fifo_in(0x1F0401)
        self.spi_wr_fifo_in(0x1E0034)
        self.spi_wr_fifo_in(0x1D0084)
        self.spi_wr_fifo_in(0x1C2924)
        self.spi_wr_fifo_in(0x190000)
        self.spi_wr_fifo_in(0x180509)
        self.spi_wr_fifo_in(0x178842)
        self.spi_wr_fifo_in(0x162300)
        self.spi_wr_fifo_in(0x14012C)
        self.spi_wr_fifo_in(0x130965)
        self.spi_wr_fifo_in(0x0E018C)
        self.spi_wr_fifo_in(0x0D4000)
        self.spi_wr_fifo_in(0x0C7001)
        self.spi_wr_fifo_in(0x0B0018)
        self.spi_wr_fifo_in(0x0A10D8)
        self.spi_wr_fifo_in(0x090302)
        self.spi_wr_fifo_in(0x081084)
        self.spi_wr_fifo_in(0x0728B2)
        self.spi_wr_fifo_in(0x041943)
        self.spi_wr_fifo_in(0x020500)
        self.spi_wr_fifo_in(0x010808)
        self.spi_wr_fifo_in(0x00221C)
        # Start spi write operation...
        self.spi_start_pulse()
    
    ##################################################################################################################################### 
    ## External PLL LMX2592
    ##################################################################################################################################### 
    def external_pll_configuration_6250(self):
        """
        Configure external PLL LMX2592 RFOUT A to generate a 6.25 GHz ADC Master CLK.
        1- Preload all SPI commands in the SPI Master input FIFO.
        2- Send all commands sending a spi_start pulse. 
        """
        self.spi_wr_fifo_in(0x00221E) 
        self.spi_wr_fifo_in(0x400077) 
        self.spi_wr_fifo_in(0x3E0000) 
        self.spi_wr_fifo_in(0x3D0001) 
        self.spi_wr_fifo_in(0x3B0000) 
        self.spi_wr_fifo_in(0x3003FC) 
        self.spi_wr_fifo_in(0x2F08CF) 
        self.spi_wr_fifo_in(0x2E17A3) 
        self.spi_wr_fifo_in(0x2D00FA) 
        self.spi_wr_fifo_in(0x2C0000) 
        self.spi_wr_fifo_in(0x2B0000) 
        self.spi_wr_fifo_in(0x2A0000) 
        self.spi_wr_fifo_in(0x2903E8) 
        self.spi_wr_fifo_in(0x280000) 
        self.spi_wr_fifo_in(0x278204) 
        self.spi_wr_fifo_in(0x26003E) 
        self.spi_wr_fifo_in(0x254000) 
        self.spi_wr_fifo_in(0x240811) 
        self.spi_wr_fifo_in(0x23021F) 
        self.spi_wr_fifo_in(0x22C3EA) 
        self.spi_wr_fifo_in(0x212A0A) 
        self.spi_wr_fifo_in(0x20210A) 
        self.spi_wr_fifo_in(0x1F0401) 
        self.spi_wr_fifo_in(0x1E0034) 
        self.spi_wr_fifo_in(0x1D0084) 
        self.spi_wr_fifo_in(0x1C2924) 
        self.spi_wr_fifo_in(0x190000) 
        self.spi_wr_fifo_in(0x180509) 
        self.spi_wr_fifo_in(0x178842) 
        self.spi_wr_fifo_in(0x162300) 
        self.spi_wr_fifo_in(0x14012C) 
        self.spi_wr_fifo_in(0x130965) 
        self.spi_wr_fifo_in(0x0E018C) 
        self.spi_wr_fifo_in(0x0D4000) 
        self.spi_wr_fifo_in(0x0C7001) 
        self.spi_wr_fifo_in(0x0B0018) 
        self.spi_wr_fifo_in(0x0A10D8) 
        self.spi_wr_fifo_in(0x090302) 
        self.spi_wr_fifo_in(0x081084) 
        self.spi_wr_fifo_in(0x0728B2) 
        self.spi_wr_fifo_in(0x041943) 
        self.spi_wr_fifo_in(0x020500) 
        self.spi_wr_fifo_in(0x010808) 
        self.spi_wr_fifo_in(0x00221C) 
        # Start spi write operation...
        self.spi_start_pulse()
            
    ##################################################################################################################################### 
    ## External PLL LMX2592
    ##################################################################################################################################### 
    def external_pll_configuration_5000(self):
        """
        Configure external PLL LMX2592 RFOUT A to generate a 5 GHz ADC Master CLK.
        1- Preload all SPI commands in the SPI Master input FIFO.
        2- Send all commands sending a spi_start pulse. 
        """
        self.spi_wr_fifo_in(0x00221E)
        self.spi_wr_fifo_in(0x400077)
        self.spi_wr_fifo_in(0x3E0000)
        self.spi_wr_fifo_in(0x3D0001)
        self.spi_wr_fifo_in(0x3B0000)
        self.spi_wr_fifo_in(0x3003FC)
        self.spi_wr_fifo_in(0x2F08CF)
        self.spi_wr_fifo_in(0x2E17A3)
        self.spi_wr_fifo_in(0x2D0000)
        self.spi_wr_fifo_in(0x2C0000)
        self.spi_wr_fifo_in(0x2B0000)
        self.spi_wr_fifo_in(0x2A0000)
        self.spi_wr_fifo_in(0x2903E8)
        self.spi_wr_fifo_in(0x280000)
        self.spi_wr_fifo_in(0x278204)
        self.spi_wr_fifo_in(0x260032)
        self.spi_wr_fifo_in(0x254000)
        self.spi_wr_fifo_in(0x240011)
        self.spi_wr_fifo_in(0x23021F)
        self.spi_wr_fifo_in(0x22C3EA)
        self.spi_wr_fifo_in(0x212A0A)
        self.spi_wr_fifo_in(0x20210A)
        self.spi_wr_fifo_in(0x1F0401)
        self.spi_wr_fifo_in(0x1E0034)
        self.spi_wr_fifo_in(0x1D0084)
        self.spi_wr_fifo_in(0x1C2924)
        self.spi_wr_fifo_in(0x190000)
        self.spi_wr_fifo_in(0x180509)
        self.spi_wr_fifo_in(0x178842)
        self.spi_wr_fifo_in(0x162300)
        self.spi_wr_fifo_in(0x14012C)
        self.spi_wr_fifo_in(0x130965)
        self.spi_wr_fifo_in(0x0E018C)
        self.spi_wr_fifo_in(0x0D4000)
        self.spi_wr_fifo_in(0x0C7001)
        self.spi_wr_fifo_in(0x0B0018)
        self.spi_wr_fifo_in(0x0A10D8)
        self.spi_wr_fifo_in(0x090302)
        self.spi_wr_fifo_in(0x081084)
        self.spi_wr_fifo_in(0x0728B2)
        self.spi_wr_fifo_in(0x041943)
        self.spi_wr_fifo_in(0x020500)
        self.spi_wr_fifo_in(0x010808)
        self.spi_wr_fifo_in(0x00221C) 
        # Start spi write operation...
        self.spi_start_pulse()
