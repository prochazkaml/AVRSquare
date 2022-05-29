#!/usr/bin/env python3

# Parameters: input_csv output_asm frequency
# Does not perform any validation checks on the input data.

import sys

csv = open(sys.argv[1], "r", errors='replace')
entries = csv.read().splitlines()
csv.close()

asm = open(sys.argv[2], "w")

# Initialize all channels

asm.write("tune:\n")
asm.write(".dw 0xFF01, 0, 0, 0, 0, 0, 0, 0, 0\n")

# Start the conversion

lastvals = [ -1 ] * 8
lastoutput = []
lastdelay = 1
delay = 0

lines = 0

entries.append("0,0,0,99999,99999,99999,99999,99999,99999,99999,99999") # Forces to flush the cache at the end of the conversion

for entry in entries:
	split = entry.split(",")

	del split[0:3]

	output = [ 0 ]

	# Check if this entry is unique to the last one or not

	for i in range(len(split)):
		if split[i] != lastvals[i]:
			output[0] |= (1 << i)
			output.append(int(split[i]) * 2)

		lastvals[i] = split[i]

	# If a new unique entry is found, flush out the old one (including its delay value)
	
	if output != [ 0 ]:
		lines = lines + 1

		if lastoutput != []:
			asm.write(".dw (0x%02X << 8) | %d" % (lastoutput[0], lastdelay))

			del lastoutput[0]

			for val in lastoutput:
				asm.write(", %d" % (val))

			asm.write("\n")

		lastoutput = output
		lastdelay = 1
	else:
		lastdelay = lastdelay + 1

# Preprocessor info

asm.write(".dw 0xFFFF\n.equ TUNE_TIMER_PRESCALER = %d\n" % (65536 / int(sys.argv[3])))

asm.close()
