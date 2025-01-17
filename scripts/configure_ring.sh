#!/usr/bin/bash

ml fpga && ml changeFPGAlinks

#https://pc2.github.io/fpgalink-gui/index.html?import=%20--fpgalink%3Dn00%3Aacl0%3Ach1-n00%3Aacl1%3Ach0%20--fpgalink%3Dn00%3Aacl1%3Ach1-n00%3Aacl2%3Ach0%20--fpgalink%3Dn00%3Aacl2%3Ach1-n00%3Aacl0%3Ach0
changeFPGAlinksXilinx --fpgalink=n00:acl0:ch1-n00:acl1:ch0 --fpgalink=n00:acl1:ch1-n00:acl2:ch0 --fpgalink=n00:acl2:ch1-n00:acl0:ch0
