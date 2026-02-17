# Moved over to [Codeberg](https://codeberg.org/prochazkaml/AVRSquare).

---

# AVRSquare
A primitive square-wave synthesizer and tune player for AVR microcontrollers. Written in AVR assembly (with avra-compatible syntax).

## Capabilities

- Play up to 8 notes at once (using 8 pins)
- ~65.536 kHz "sample" rate

[Here's a demo of this program playing the intro tune from 8088 MPH.](https://youtu.be/OVE0jGiZFQk)

## Supported devices

- ATmega328P
- ATmega644(A)

These devices already have their respective include files in the [devices](https://github.com/prochazkaml/AVRSquare/tree/master/devices) directory and have official support in [devicelist.asm](https://github.com/prochazkaml/AVRSquare/blob/master/devicelist.asm).

## Prerequisites

**For initial testing, you can safely skip this and jump straight to the Configuration section.** An example tune.asm file is already present in this repository (converted from [SWINGING.MON](https://github.com/prochazkaml/Polytone/blob/master/examples/SWINGING.MON)).

First of all (if you don't want to code music directly in assembly), you need to create or load an existing compatible music file (.MON, .POL) using [Polytone](https://github.com/prochazkaml/Polytone), a square-wave tracker which is capable of exporting the tune into a CSV file containing raw frequencies.

Besides the Polytone repository, which already contains some example files, you can find some more [here](https://github.com/MobyGamer/MONOTONE).

When you get your CSV, it's time to convert it to AVR assembly using the following command (requires Python 3):

```bash
./csv2asm.py <input csv> <output asm> <frequency>
```

The `<input csv>` and `<output asm>` parameters are quite self-explanatory, the `<frequency>` parameter indicates the tracker update frequency of the song. Usually, this value is either 50 or 60, but to be 100% sure, you can try playing the song in Polytone, as it tells you the current frequency in the bottom status bar.

Beware that the output file has to be named `tune.asm`, unless you change the `.include` directive at the bottom of [main.asm](https://github.com/prochazkaml/AVRSquare/blob/master/main.asm).

With all of that, an example command would be:

```bash
./csv2asm.py ~/Downloads/Polytone/swinging.csv tune.asm 60
```

## Configuration

Next you need to select your target microcontroller, which is done by changing [line 14 of main.asm](https://github.com/prochazkaml/AVRSquare/blob/master/main.asm#L14).

For all compatible devices, see the top of [devicelist.asm](https://github.com/prochazkaml/AVRSquare/blob/master/devicelist.asm) (section `DEVICE DEFINITIONS`).

In case you wish to port this to other AVRs, please keep the following in mind:

- Some AVRs have different procedures for setting up the first 8-bit timer (Timer0 in most cases). Please refer to their respective manuals for more information on how that is done.
- The initialization routine must fit in the empty space before the timer interrupt vector (to save space). In case it does not (as some AVRs have different vector table layouts), move the initialization routine after the timer interrupt routine and perform a jump at the reset vector to it.
- Port D is used by default, as it is the only usable full 8-bit port on the ATmega328P. Some AVRs lack this port, so it might have to be changed in [main.asm](https://github.com/prochazkaml/AVRSquare/blob/master/main.asm) under the section `REGISTER DEFINITIONS`.
- You will need to get the include file for your microcontroller and implement it in [devicelist.asm](https://github.com/prochazkaml/AVRSquare/blob/master/devicelist.asm). You can find include files in the [avra repository](https://github.com/Ro5bert/avra/tree/master/includes).

## Build

After you have converted your tune into the file `tune.asm` and configured your target, you can finally perform the build and write it to your AVR:

```
avra main.asm
```

If you are using an Arduino, use the following command to upload the program (on Linux):

```
avrdude -c arduino -p atmega328p -P /dev/ttyUSB0 -b 115200 -U flash:w:main.hex:i
```

If you are using other AVRs (or a barebones ATmega328P) with the USBasp programmer, use the following command instead:

```
avrdude -c usbasp -p <yourpart> -U flash:w:main.hex:i
```

Remember to substitute `<yourpart>` with your part (eg. `atmega328p`, `atmega644` etc.).

If you have some other programmer, I'm sure you can figure it out yourself.

## Connection

Each channel has its own output on one of the pins of the selected I/O port (by default, this is port D, in other words digital pins 0-7 on Arduino), which have to be mixed together.

This can be done either by connecting 8 resistors (preferably 1K or more) to each pin by one end and then tying them together at the other end, which becomes your audio output. This can be either amplified, or connected to headphones (for me, 10K resistors give a pleasant output volume on my Sony MDR-ZX110's).

Alternatively, you may use an 8x resistor network, whose 8 "end" pins you connect to the 8 AVR pins and the remaining pin (the one on the edge which has a large dot printed on the body above the pin) becomes your audio output. For example, look for [9-pin A103J](https://www.google.com/search?q=A103J+9+pin).

That's it, enjoy!
