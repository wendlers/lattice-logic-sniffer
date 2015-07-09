##
# The MIT License (MIT)
#
# Copyright (c) 2015 Stefan Wendler
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
##

import struct
import serial
import tempfile
import subprocess

MHz = 1000000
KHz = 1000
Hz = 1

class RegIoUartDriver(object):
    """
    Low level FPGA register access using serial line.
    """

    def __init__(self, port='/dev/ttyUSB1', baudrate=921600, timeout=1):
        """

        :param port:
        :param baudrate:
        :param timeout:
        :return:
        """
        self.serial = serial.Serial(port=port, baudrate=baudrate, timeout=timeout)

    def read(self, register, count=0):
        """

        :param register:
        :param count:
        :return:
        """
        if count:
            self.serial.write(''.join([chr(register), chr(0xff & count)]))
            mem = self.serial.read(count)
            return [ord(x) for x in mem]
        else:
            self.serial.write(chr(register))
            return ord(self.serial.read(1))

    def write(self, register, value):
        """

        :param register:
        :param value:
        :return:
        """
        self.serial.write(''.join([chr(0x80 | register), chr(0xff & value)]))


class LogicSnifferDriver(object):
    """
    Access the FPGA registers through Python properties.
    """

    MAX_SAMPLE_CLK = 48 * MHz
    MEM_SIZE = 0x4000

    REG_LED = 0x00
    REG_MEMADR_RD_LO = 0x01
    REG_MEMADR_RD_HI = 0x02
    REG_MEMADR_WR_LO = 0x03
    REG_MEMADR_WR_HI = 0x04
    REG_MEM = 0x05
    REG_STATUS = 0x06
    REG_TRIG_EN = 0x07
    REG_TRIG_VAL = 0x08
    REG_CLKDIV_LO = 0x09
    REG_CLKDIV_HI = 0x0A

    LED_0 = 0b00000001
    LED_1 = 0b00000010
    LED_2 = 0b00000100
    LED_3 = 0b00001000
    LED_4 = 0b00010000
    LED_5 = 0b00100000
    LED_6 = 0b01000000
    LED_7 = 0b10000000

    PIN_0 = 0b00000001
    PIN_1 = 0b00000010
    PIN_2 = 0b00000100
    PIN_3 = 0b00001000
    PIN_4 = 0b00010000
    PIN_5 = 0b00100000
    PIN_6 = 0b01000000
    PIN_7 = 0b10000000

    def __init__(self, reg_io):
        """

        :param reg_io:
        :return:
        """
        self.rio = reg_io

        self.rio.write(LogicSnifferDriver.REG_LED, 0)

    def __del__(self):
        """

        :return:
        """
        self.rio.write(LogicSnifferDriver.REG_LED, 0)

    @property
    def status(self):
        """

        :return:
        """
        return self.rio.read(LogicSnifferDriver.REG_STATUS)

    @status.setter
    def status(self, value):
        """

        :param value:
        :return:
        """
        self.rio.write(LogicSnifferDriver.REG_STATUS, 0xff & value)

    @property
    def led(self):
        """

        :return:
        """
        return self.rio.read(LogicSnifferDriver.REG_LED)

    @led.setter
    def led(self, value):
        """

        :param value:
        :return:
        """
        self.rio.write(LogicSnifferDriver.REG_LED, 0xff & value)

    @property
    def mem_rd_address(self):
        """

        :return:
        """
        return (self.rio.read(LogicSnifferDriver.REG_MEMADR_RD_LO) |
                (self.rio.read(LogicSnifferDriver.REG_MEMADR_RD_HI) << 8)) & 0xffff

    @mem_rd_address.setter
    def mem_rd_address(self, value):
        """

        :param value:
        :return:
        """
        self.rio.write(LogicSnifferDriver.REG_MEMADR_RD_LO, (value >> 0) & 0xff)
        self.rio.write(LogicSnifferDriver.REG_MEMADR_RD_HI, (value >> 8) & 0xff)

    @property
    def mem_wr_address(self):
        """

        :return:
        """
        return (self.rio.read(LogicSnifferDriver.REG_MEMADR_WR_LO) |
                (self.rio.read(LogicSnifferDriver.REG_MEMADR_WR_HI) << 8)) & 0xffff

    @property
    def mem(self):
        """

        :return:
        """

        # set initial read address to 0
        self.mem_rd_address = 0

        samples = []

        led_state = 0x00
        led_bit = 1
        junk_size = 0x80
        mem_size = LogicSnifferDriver.MEM_SIZE / junk_size
        step_cnt = mem_size / 8

        self.led = led_state

        for i in range(mem_size):

            if i % step_cnt == 0:
                led_state |= led_bit
                led_bit <<= 1
                self.led = led_state

            samples += self.rio.read(LogicSnifferDriver.REG_MEM, junk_size)

        return samples

    @property
    def trigger_en(self):
        """

        :return:
        """
        return self.rio.read(LogicSnifferDriver.REG_TRIG_EN)

    @trigger_en.setter
    def trigger_en(self, value):
        """

        :param value:
        :return:
        """
        self.rio.write(LogicSnifferDriver.REG_TRIG_EN, 0xff & value)

    @property
    def trigger_val(self):
        """

        :return:
        """
        return self.rio.read(LogicSnifferDriver.REG_TRIG_VAL)

    @trigger_val.setter
    def trigger_val(self, value):
        """

        :param value:
        :return:
        """
        self.rio.write(LogicSnifferDriver.REG_TRIG_VAL, 0xff & value)

    @property
    def sample_clk_div(self):
        """

        :return:
        """
        return (self.rio.read(LogicSnifferDriver.REG_CLKDIV_LO) |
                (self.rio.read(LogicSnifferDriver.REG_CLKDIV_HI) << 8)) & 0xffff

    @sample_clk_div.setter
    def sample_clk_div(self, value):
        """

        :param value:
        :return:
        """
        self.rio.write(LogicSnifferDriver.REG_CLKDIV_LO, (value >> 0) & 0xff)
        self.rio.write(LogicSnifferDriver.REG_CLKDIV_HI, (value >> 8) & 0xff)


class LogicSniffer(object):
    """
    High level access to the logic sniffer functionality.
    """

    def __init__(self, ls_drv):
        """

        :param ls_drv:
        :return:
        """
        self.drv = ls_drv

        self._sample_clk = LogicSnifferDriver.MAX_SAMPLE_CLK
        self._sample_count = LogicSnifferDriver.MEM_SIZE
        self._trigger_en = 0
        self._trigger_val = 0
        self._samples = []

    def __del__(self):
        """

        :return:
        """
        pass

    @property
    def sample_clock(self):
        """

        :return:
        """
        return self._sample_clk

    @sample_clock.setter
    def sample_clock(self, value):
        """

        Valid clocks:

         48 * MHz       => highest freq!
         24 * MHz
         16 * MHz
         12 * MHz
           8 * MHz
           6 * MHz
           4 * MHz
           2 * MHz
           1 * MHz
         800 * KHz
         600 * KHz
         400 * KHz
         200 * KHz
         100 * KHz
          80 * KHz
          ...
          10 * KHz
           8 * KHz
          ...
           1 * KHz
         800 * Hz       => smalles freq!

        :param value:
        :return:
        """
        assert value <= LogicSnifferDriver.MAX_SAMPLE_CLK
        assert value > 799

        self._sample_clk = value

    @property
    def trigger(self):
        """

        :return:
        """
        return self._trigger_en, self._trigger_val

    @trigger.setter
    def trigger(self, value):
        """

        :param value:
        :return:
        """
        self._trigger_en = value[0]
        self._trigger_val = value[1]

    @property
    def samples(self):
        """

        :return:
        """
        return self._samples

    def sample(self, use_trigger=False):
        """

        :param use_trigger:
        :return:
        """
        self._samples = []

        # set sample clock divider
        self.drv.sample_clk_div = int(LogicSnifferDriver.MAX_SAMPLE_CLK / self._sample_clk)

        if use_trigger:

            self.drv.trigger_en = self._trigger_en
            self.drv.trigger_val = self._trigger_val

            # enable sampling and trigger
            self.drv.status = 0x05

        else:

            # enable sampling
            self.drv.status = 0x01

        # wait until sampling is done
        while self.drv.status & 0x01:
            pass

        # read back the samples
        self._samples = self.drv.mem

    def write_raw(self, file_name):

        with open(file_name, 'wb') as f:

            for c in self._samples:
                f.write(struct.pack('B', c))

    def write_sr(self, file_name):

        temp = tempfile.NamedTemporaryFile(delete=False)

        try:
            for c in self._samples:
                temp.write(struct.pack('B', c))
        finally:
            temp.close()

        subprocess.call(['sigrok-cli',
                         '-I', 'binary:numchannels=8:samplerate=%d' % self._sample_clk,
                         '-i', temp.name,
                         '-o', file_name])

    def write_vcd(self, file_name, module='LogicSniffer'):
        """

        :param file_name:
        :param module:
        :return:
        """
        pin_map = {0: 'A', 1: 'B', 2: 'C', 3: 'D', 4: 'E', 5: 'F', 6: 'G', 7: 'H'}

        # timescale = 1000000000 / self._sample_clk

        with open(file_name, 'w') as f:
            # f.write('$timescale %fns $end\n' % timescale)
            f.write('$timescale 166us $end\n')
            f.write('$scope module %s $end\n' % module)

            for k, v in pin_map.iteritems():
                f.write('$var wire 1 %s PIN%d $end\n' % (v, k))

            f.write('$upscope $end\n')
            f.write('$enddefinitions $end\n')

            t = 0

            for t in range(len(self._samples)):

                if t == 0:

                    f.write('#%d\n' % t)

                    for j in range(8):
                        if (self._samples[t] >> j) & 1:
                            f.write('1%s\n' % pin_map[j])
                        else:
                            f.write('0%s\n' % pin_map[j])

                elif self._samples[t] != self._samples[t - 1]:

                    f.write('#%d\n' % t)

                    for j in range(8):
                        if (self._samples[t] >> j) & 1 != (self._samples[t - 1] >> j) & 1:
                            if (self._samples[t] >> j) & 1:
                                f.write('1%s\n' % pin_map[j])
                            else:
                                f.write('0%s\n' % pin_map[j])

            f.write('#%d\n' % t)

    def dump_samples(self):
        """

        :return:
        """
        i = 0

        for s in self._samples:

            if i % 32 == 0:
                print('\n%04x |' % i),

            print('%02x' % s),

            i += 1


if __name__ == "__main__":

    rio = RegIoUartDriver()
    lsd = LogicSnifferDriver(rio)
    lsn = LogicSniffer(lsd)

    lsn.sample_clock = 48 * MHz     # LogicSnifferDriver.MAX_SAMPLE_CLK
    lsn.trigger = (0xff, 0x01)
    lsn.sample(use_trigger=True)

    lsn.dump_samples()
    lsn.write_vcd('test.vcd')
    lsn.write_sr('test.sr')
